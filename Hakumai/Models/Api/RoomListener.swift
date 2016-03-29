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
private let kPingInterval: NSTimeInterval = 60

// MARK: protocol

protocol RoomListenerDelegate: class {
    func roomListenerDidReceiveThread(roomListener: RoomListener, thread: Thread)
    func roomListenerDidReceiveChat(roomListener: RoomListener, chat: Chat)
    func roomListenerDidFinishListening(roomListener: RoomListener)
}

// MARK: main

class RoomListener : NSObject, NSStreamDelegate {
    weak var delegate: RoomListenerDelegate?
    let server: MessageServer?
    
    var runLoop: NSRunLoop!
    
    var inputStream: NSInputStream?
    var outputStream: NSOutputStream?
    var pingTimer: NSTimer?
    
    var parsingString: NSString = ""
    
    var thread: Thread?
    var startDate: NSDate?
    var lastRes: Int = 0
    var internalNo: Int = 0
    
    private let fileLogger = XCGLogger()
    
    init(delegate: RoomListenerDelegate?, server: MessageServer?) {
        self.delegate = delegate
        self.server = server
        
        super.init()
        
        initializeFileLogger()
        logger.info("listener initialized for message server:\(self.server)")
    }
    
    deinit {
        logger.debug("")
    }
    
    func initializeFileLogger() {
        var logNumber = 0
        if let server = server {
            logNumber = server.roomPosition.rawValue
        }
        
        let fileName = kFileLogNamePrefix + String(logNumber) + kFileLogNameSuffix
        Helper.setupFileLogger(fileLogger, fileName: fileName)
    }
    
    // MARK: - Public Functions
    func openSocket(resFrom: Int = 0) {
        guard let server = server else {
            return
        }
        
        var input :NSInputStream?
        var output :NSOutputStream?
        
        NSStream.getStreamsToHostWithName(server.address, port: server.port, inputStream: &input, outputStream: &output)
        
        if input == nil || output == nil {
            fileLogger.error("failed to open socket.")
            return
        }
        
        inputStream = input
        outputStream = output
        
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        runLoop = NSRunLoop.currentRunLoop()
        
        inputStream?.scheduleInRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
        outputStream?.scheduleInRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
        
        inputStream?.open()
        outputStream?.open()
        
        let message = "<thread thread=\"\(server.thread)\" res_from=\"-\(resFrom)\" version=\"20061206\"/>"
        sendMessage(message)
        
        startPingTimer()

        while inputStream != nil {
            runLoop.runUntilDate(NSDate(timeIntervalSinceNow: NSTimeInterval(1)))
        }
        
        delegate?.roomListenerDidFinishListening(self)
    }
    
    func closeSocket() {
        fileLogger.debug("closed streams.")
        
        stopPingTimer()

        inputStream?.delegate = nil
        outputStream?.delegate = nil
        
        inputStream?.close()
        outputStream?.close()
        
        inputStream?.removeFromRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
        outputStream?.removeFromRunLoop(runLoop, forMode: NSDefaultRunLoopMode)
        
        inputStream = nil
        outputStream = nil
    }
    
    func comment(live: Live, user: User, postKey: String, comment: String, anonymously: Bool) {
        guard let thread = thread else {
            logger.debug("could not get thread information")
            return
        }
        
        let threadNumber = thread.thread!
        let ticket = thread.ticket!
        let originTime = Int(thread.serverTime!.timeIntervalSince1970) - Int(live.baseTime!.timeIntervalSince1970)
        let elapsedTime = Int(NSDate().timeIntervalSince1970) - Int(startDate!.timeIntervalSince1970)
        let vpos = (originTime + elapsedTime) * 100
        let mail = anonymously ? "184" : ""
        let userId = user.userId!
        let premium = user.isPremium!
        
        let message = "<chat thread=\"\(threadNumber)\" ticket=\"\(ticket)\" vpos=\"\(vpos)\" postkey=\"\(postKey)\" mail=\"\(mail)\" user_id=\"\(userId)\" premium=\"\(premium)\">\(comment)</chat>"
        
        sendMessage(message)
    }
    
    func sendMessage(message: String, logging: Bool = true) {
        let data: NSData = (message + "\0").dataUsingEncoding(NSUTF8StringEncoding)!
        outputStream?.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
 
        if logging {
            logger.debug(message)
        }
    }
    
    // MARK: - NSStreamDelegate Functions
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            fileLogger.debug("stream event none")
            
        case NSStreamEvent.OpenCompleted:
            fileLogger.debug("stream event open completed")
            
        case NSStreamEvent.HasBytesAvailable:
            // fileLogger.debug("stream event has bytes available")
            
            // http://stackoverflow.com/q/26360962
            var readByte = [UInt8](count: kReadBufferSize, repeatedValue: 0)
            
            var actualRead = 0
            while inputStream?.hasBytesAvailable == true {
                actualRead = inputStream!.read(&readByte, maxLength: kReadBufferSize)
                //fileLogger.debug(readByte)
                
                if let readString = NSString(bytes: &readByte, length: actualRead, encoding: NSUTF8StringEncoding) {
                    fileLogger.debug("read: [ \(readString) ]")
                    
                    parsingString = parsingString as String + streamByRemovingNull(readString as String)
                    
                    if !hasValidCloseBracket(parsingString as String) {
                        fileLogger.warning("detected no-close-bracket stream, continue reading...")
                        continue
                    }
                    
                    if !hasValidOpenBracket(parsingString as String) {
                        fileLogger.warning("detected no-open-bracket stream, clearing buffer and continue reading...")
                        parsingString = ""
                        continue
                    }
                    
                    parseInputStream(parsingString as String)
                    parsingString = ""
                }
            }
            
            
        case NSStreamEvent.HasSpaceAvailable:
            fileLogger.debug("stream event has space available")
            
        case NSStreamEvent.ErrorOccurred:
            fileLogger.error("stream event error occurred")
            closeSocket()
            
        case NSStreamEvent.EndEncountered:
            fileLogger.debug("stream event end encountered")
            
        default:
            fileLogger.warning("unexpected stream event")
        }
    }

    // MARK: Read Utility
    func streamByRemovingNull(stream: String) -> String {
        let regexp = try! NSRegularExpression(pattern: "\0", options: [])
        let removed = regexp.stringByReplacingMatchesInString(stream, options: [], range: NSMakeRange(0, stream.utf16.count), withTemplate: "")
        
        return removed
    }
    
    func hasValidOpenBracket(stream: String) -> Bool {
        return hasValidPatternInStream("^<", stream: stream)
    }
    
    func hasValidCloseBracket(stream: String) -> Bool {
        return hasValidPatternInStream(">$", stream: stream)
    }
    
    func hasValidPatternInStream(pattern: String, stream: String) -> Bool {
        let regexp = try! NSRegularExpression(pattern: pattern, options: [])
        let matched = regexp.firstMatchInString(stream, options: [], range: NSMakeRange(0, stream.utf16.count))
        
        return matched != nil ? true : false
    }
    
    // MARK: - Parse Utility
    func parseInputStream(stream: String) {
        let wrappedStream = "<items>" + stream + "</items>"
        fileLogger.verbose("parsing: [ \(wrappedStream) ]")
        
        var err: NSError?
        let xmlDocument: NSXMLDocument?
        do {
            xmlDocument = try NSXMLDocument(XMLString: wrappedStream, options: Int(NSXMLDocumentTidyXML))
        } catch let error as NSError {
            err = error
            logger.error("\(err)")
            xmlDocument = nil
        }
        
        if xmlDocument == nil {
            fileLogger.error("could not parse input stream:\(stream)")
            return
        }
        
        if let rootElement = xmlDocument?.rootElement() {
            // rootElement = '<items>...</item>'

            let threads = parseThreadElement(rootElement)
            for _thread in threads {
                thread = _thread
                lastRes = _thread.lastRes!
                startDate = NSDate()
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
                logger.debug("\(chatResult.description)")
            }
        }
    }
    
    func parseThreadElement(rootElement: NSXMLElement) -> [Thread] {
        var threads = [Thread]()
        let threadElements = rootElement.elementsForName("thread")
        
        for threadElement in threadElements {
            let thread = Thread()

            if let rc = threadElement.attributeForName("resultcode")?.stringValue, let intrc = Int(rc) {
                thread.resultCode = intrc
            }

            if let th = threadElement.attributeForName("thread")?.stringValue, let intth = Int(th) {
                thread.thread = intth
            }

            if let lr = threadElement.attributeForName("last_res")?.stringValue, let intlr = Int(lr) {
                thread.lastRes = intlr
            }
            else {
                thread.lastRes = 0
            }
            
            thread.ticket = threadElement.attributeForName("ticket")?.stringValue

            if let st = threadElement.attributeForName("server_time")?.stringValue, let intst = Int(st) {
                thread.serverTime = intst.toDateAsTimeIntervalSince1970()
            }

            threads.append(thread)
        }
        
        return threads
    }
    
    func parseChatElement(rootElement: NSXMLElement) -> [Chat] {
        var chats = [Chat]()
        let chatElements = rootElement.elementsForName("chat")
        
        for chatElement in chatElements {
            let chat = Chat()

            chat.internalNo = internalNo
            internalNo += 1
            chat.roomPosition = server?.roomPosition
            
            if let pr = chatElement.attributeForName("premium")?.stringValue, let intpr = Int(pr) {
                chat.premium = Premium(rawValue: intpr)
            }
            else {
                // assume no attribute provided as Ippan(0)
                chat.premium = Premium(rawValue: 0)
            }
            
            if let sc = chatElement.attributeForName("score")?.stringValue, let intsc = Int(sc) {
                chat.score = intsc
            }
            else {
                chat.score = 0
            }

            if let no = chatElement.attributeForName("no")?.stringValue, let intno = Int(no) {
                chat.no = intno
            }

            if let dt = chatElement.attributeForName("date")?.stringValue, let intdt = Int(dt) {
                chat.date = intdt.toDateAsTimeIntervalSince1970()
            }

            if let du = chatElement.attributeForName("date_usec")?.stringValue, let intdu = Int(du) {
                chat.dateUsec = intdu
            }

            if let separated = chatElement.attributeForName("mail")?.stringValue?.componentsSeparatedByString(" ") {
                chat.mail = separated
            }

            chat.userId = chatElement.attributeForName("user_id")?.stringValue
            chat.comment = chatElement.stringValue
            
            if chat.no == nil || chat.userId == nil || chat.comment == nil {
                logger.warning("skipped invalid chat:[\(chat)]")
                continue
            }
            
            chats.append(chat)
        }
        
        return chats
    }
    
    func parseChatResultElement(rootElement: NSXMLElement) -> [ChatResult] {
        var chatResults = [ChatResult]()
        let chatResultElements = rootElement.elementsForName("chat_result")
        
        for chatResultElement in chatResultElements {
            let chatResult = ChatResult()
            
            if let st = chatResultElement.attributeForName("status")?.stringValue, let intst = Int(st) {
                chatResult.status = ChatResult.Status(rawValue: intst)
            }
            
            chatResults.append(chatResult)
        }
        
        return chatResults
    }

    // MARK: - Private Functions
    func startPingTimer() {
        pingTimer = NSTimer.scheduledTimerWithTimeInterval(
            kPingInterval, target: self, selector: Selector("sendPing:"), userInfo: nil, repeats: true)
    }

    func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    func sendPing(timer: NSTimer) {
        sendMessage("<ping>PING</ping>", logging: false)
    }
}
