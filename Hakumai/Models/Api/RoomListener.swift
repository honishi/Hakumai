//
//  RoomListener.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/16/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

private let kFileLogNamePrefix = "Hakumai_"
private let kFileLogNameSuffix = ".log"

private let kReadBufferSize = 102400
private let kPingInterval: TimeInterval = 60

// MARK: protocol

protocol RoomListenerDelegate: class {
    func roomListenerDidReceiveThread(_ roomListener: RoomListener, thread: Thread)
    func roomListenerDidReceiveChat(_ roomListener: RoomListener, chat: Chat)
    func roomListenerDidFinishListening(_ roomListener: RoomListener)
}

// MARK: main

final class RoomListener: NSObject, StreamDelegate {
    weak var delegate: RoomListenerDelegate?
    let server: MessageServer?

    private var runLoop: RunLoop!

    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var pingTimer: Timer?

    private var parsingString: String = ""

    private var thread: Thread?
    private var startDate: Date?
    private(set) var lastRes: Int = 0
    private var internalNo: Int = 0

    private let fileLog = XCGLogger()

    init(delegate: RoomListenerDelegate?, server: MessageServer?) {
        self.delegate = delegate
        self.server = server

        super.init()

        initializeFileLogger()
        log.info("listener initialized for message server:\(self.server?.description ?? "")")
    }

    deinit {
        log.debug("")
    }
}

extension RoomListener {
    private func initializeFileLogger() {
        var logNumber = 0
        if let server = server {
            logNumber = server.roomPosition.rawValue
        }

        let fileName = kFileLogNamePrefix + String(logNumber) + kFileLogNameSuffix
        Helper.setupFileLogger(fileLog, fileName: fileName)
    }

    // MARK: - Public Functions
    func openSocket(resFrom: Int = 0) {
        guard let server = server else { return }

        var input: InputStream?
        var output: OutputStream?

        Stream.getStreamsToHost(withName: server.address, port: server.port, inputStream: &input, outputStream: &output)

        if input == nil || output == nil {
            fileLog.error("failed to open socket.")
            return
        }

        inputStream = input
        outputStream = output

        inputStream?.delegate = self
        outputStream?.delegate = self

        runLoop = RunLoop.current

        inputStream?.schedule(in: runLoop, forMode: RunLoop.Mode.default)
        outputStream?.schedule(in: runLoop, forMode: RunLoop.Mode.default)

        inputStream?.open()
        outputStream?.open()

        let message = "<thread thread=\"\(server.thread)\" res_from=\"-\(resFrom)\" version=\"20061206\"/>"
        send(message: message)

        startPingTimer()

        while inputStream != nil {
            runLoop.run(until: Date(timeIntervalSinceNow: TimeInterval(1)))
        }

        delegate?.roomListenerDidFinishListening(self)
    }

    func closeSocket() {
        fileLog.debug("closed streams.")

        stopPingTimer()

        inputStream?.delegate = nil
        outputStream?.delegate = nil

        inputStream?.close()
        outputStream?.close()

        inputStream?.remove(from: runLoop, forMode: RunLoop.Mode.default)
        outputStream?.remove(from: runLoop, forMode: RunLoop.Mode.default)

        inputStream = nil
        outputStream = nil
    }

    func comment(live: Live, user: User, postKey: String, comment: String, anonymously: Bool) {
        guard let thread = thread, let threadNumber = thread.thread, let ticket = thread.ticket,
              let serverTime = thread.serverTime, let baseTime = live.baseTime, let startDate = startDate,
              let userId = user.userId, let premium = user.isPremium else {
            log.debug("could not get thread information")
            return
        }
        let originTime = Int(serverTime.timeIntervalSince1970) - Int(baseTime.timeIntervalSince1970)
        let elapsedTime = Int(Date().timeIntervalSince1970) - Int(startDate.timeIntervalSince1970)
        let vpos = (originTime + elapsedTime) * 100
        let mail = anonymously ? "184" : ""
        let message = "<chat thread=\"\(threadNumber)\" ticket=\"\(ticket)\" vpos=\"\(vpos)\" postkey=\"\(postKey)\" mail=\"\(mail)\" user_id=\"\(userId)\" premium=\"\(premium)\">\(comment)</chat>"
        send(message: message)
    }

    private func send(message: String, logging: Bool = true) {
        guard let data = (message + "\0").data(using: String.Encoding.utf8) else { return }
        outputStream?.write((data as NSData).bytes.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
        if logging {
            log.debug(message)
        }
    }

    // MARK: - NSStreamDelegate Functions
    // swiftlint:disable cyclomatic_complexity
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event():
            fileLog.debug("stream event none")

        case Stream.Event.openCompleted:
            fileLog.debug("stream event open completed")

        case Stream.Event.hasBytesAvailable:
            // fileLog.debug("stream event has bytes available")
            guard let inputStream = inputStream else { return }
            // http://stackoverflow.com/q/26360962
            var readByte = [UInt8](repeating: 0, count: kReadBufferSize)
            var actualRead = 0
            while inputStream.hasBytesAvailable == true {
                actualRead = inputStream.read(&readByte, maxLength: kReadBufferSize)
                //fileLog.debug(readByte)
                if let readString = NSString(bytes: &readByte, length: actualRead, encoding: String.Encoding.utf8.rawValue) {
                    fileLog.debug("read: [ \(readString) ]")
                    parsingString += streamByRemovingNull(fromStream: readString as String)
                    if !hasValidCloseBracket(inStream: parsingString) {
                        fileLog.warning("detected no-close-bracket stream, continue reading...")
                        continue
                    }
                    if !hasValidOpenBracket(inStream: parsingString) {
                        fileLog.warning("detected no-open-bracket stream, clearing buffer and continue reading...")
                        parsingString = ""
                        continue
                    }
                    parseInputStream(parsingString)
                    parsingString = ""
                }
            }

        case Stream.Event.hasSpaceAvailable:
            fileLog.debug("stream event has space available")

        case Stream.Event.errorOccurred:
            fileLog.error("stream event error occurred")
            closeSocket()

        case Stream.Event.endEncountered:
            fileLog.debug("stream event end encountered")

        default:
            fileLog.warning("unexpected stream event")
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // MARK: Read Utility
    func streamByRemovingNull(fromStream stream: String) -> String {
        guard let regexp = try? NSRegularExpression(pattern: "\0", options: []) else { return stream }
        return regexp.stringByReplacingMatches(
            in: stream,
            options: [],
            range: NSRange(location: 0, length: stream.utf16.count),
            withTemplate: "")
    }

    func hasValidOpenBracket(inStream stream: String) -> Bool {
        return hasValid(pattern: "^<", inStream: stream)
    }

    func hasValidCloseBracket(inStream stream: String) -> Bool {
        return hasValid(pattern: ">$", inStream: stream)
    }

    private func hasValid(pattern: String, inStream stream: String) -> Bool {
        guard let regexp = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let matched = regexp.firstMatch(
            in: stream,
            options: [],
            range: NSRange(location: 0, length: stream.utf16.count))
        return matched != nil
    }

    // MARK: - Parse Utility
    private func parseInputStream(_ stream: String) {
        let wrappedStream = "<items>" + stream + "</items>"
        fileLog.verbose("parsing: [ \(wrappedStream) ]")

        var err: NSError?
        let xmlDocument: XMLDocument?
        do {
            // NSXMLDocumentTidyXML
            xmlDocument = try XMLDocument(xmlString: wrappedStream, options: convertToXMLNodeOptions(Int(UInt(XMLDocument.ContentKind.xml.rawValue))))
        } catch let error as NSError {
            err = error
            log.error("\(err?.debugDescription ?? "")")
            xmlDocument = nil
        }

        if xmlDocument == nil {
            fileLog.error("could not parse input stream:\(stream)")
            return
        }

        if let rootElement = xmlDocument?.rootElement() {
            // rootElement = '<items>...</item>'

            let threads = parseThreadElement(rootElement)
            for _thread in threads {
                thread = _thread
                lastRes = _thread.lastRes ?? 0
                startDate = Date()
                delegate?.roomListenerDidReceiveThread(self, thread: _thread)
            }

            let chats = parseChatElement(rootElement)
            for chat in chats {
                if let chatNo = chat.no {
                    lastRes = chatNo
                }
                delegate?.roomListenerDidReceiveChat(self, chat: chat)
            }

            let chatResults = parseChatResultElement(rootElement)
            for chatResult in chatResults {
                log.debug("\(chatResult.description)")
            }
        }
    }

    func parseThreadElement(_ rootElement: XMLElement) -> [Thread] {
        var threads = [Thread]()
        let threadElements = rootElement.elements(forName: "thread")

        for threadElement in threadElements {
            let thread = Thread()

            if let rc = threadElement.attribute(forName: "resultcode")?.stringValue, let intrc = Int(rc) {
                thread.resultCode = intrc
            }

            if let th = threadElement.attribute(forName: "thread")?.stringValue, let intth = Int(th) {
                thread.thread = intth
            }

            if let lr = threadElement.attribute(forName: "last_res")?.stringValue, let intlr = Int(lr) {
                thread.lastRes = intlr
            } else {
                thread.lastRes = 0
            }

            thread.ticket = threadElement.attribute(forName: "ticket")?.stringValue

            if let st = threadElement.attribute(forName: "server_time")?.stringValue, let intst = Int(st) {
                thread.serverTime = intst.toDateAsTimeIntervalSince1970()
            }

            threads.append(thread)
        }

        return threads
    }

    func parseChatElement(_ rootElement: XMLElement) -> [Chat] {
        var chats = [Chat]()
        let chatElements = rootElement.elements(forName: "chat")

        for chatElement in chatElements {
            let chat = Chat()

            chat.internalNo = internalNo
            internalNo += 1
            chat.roomPosition = server?.roomPosition

            if let pr = chatElement.attribute(forName: "premium")?.stringValue, let intpr = Int(pr) {
                chat.premium = Premium(rawValue: intpr)
            } else {
                // assume no attribute provided as Ippan(0)
                chat.premium = Premium(rawValue: 0)
            }

            if let sc = chatElement.attribute(forName: "score")?.stringValue, let intsc = Int(sc) {
                chat.score = intsc
            } else {
                chat.score = 0
            }

            if let no = chatElement.attribute(forName: "no")?.stringValue, let intno = Int(no) {
                chat.no = intno
            } else {
                chat.no = 0
            }

            if let dt = chatElement.attribute(forName: "date")?.stringValue, let intdt = Int(dt) {
                chat.date = intdt.toDateAsTimeIntervalSince1970()
            }

            if let du = chatElement.attribute(forName: "date_usec")?.stringValue, let intdu = Int(du) {
                chat.dateUsec = intdu
            }

            if let separated = chatElement.attribute(forName: "mail")?.stringValue?.components(separatedBy: " ") {
                chat.mail = separated
            }

            chat.userId = chatElement.attribute(forName: "user_id")?.stringValue
            chat.comment = chatElement.stringValue

            if chat.no == nil || chat.userId == nil || chat.comment == nil {
                log.warning("skipped invalid chat:[\(chat)]")
                continue
            }

            chats.append(chat)
        }

        return chats
    }

    private func parseChatResultElement(_ rootElement: XMLElement) -> [ChatResult] {
        var chatResults = [ChatResult]()
        let chatResultElements = rootElement.elements(forName: "chat_result")

        for chatResultElement in chatResultElements {
            let chatResult = ChatResult()

            if let st = chatResultElement.attribute(forName: "status")?.stringValue, let intst = Int(st) {
                chatResult.status = ChatResult.Status(rawValue: intst)
            }

            chatResults.append(chatResult)
        }

        return chatResults
    }

    // MARK: - Private Functions
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(
            timeInterval: kPingInterval, target: self, selector: #selector(RoomListener.sendPing(_:)), userInfo: nil, repeats: true)
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    @objc func sendPing(_ timer: Timer) {
        send(message: "<ping>PING</ping>", logging: false)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToXMLNodeOptions(_ input: Int) -> XMLNode.Options {
    return XMLNode.Options(rawValue: UInt(input))
}
