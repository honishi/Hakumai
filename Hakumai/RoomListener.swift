//
//  RoomListener.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/16/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// MARK: protocol

protocol RoomListenerDelegate {
    func roomListenerDidStartListening(roomListener: RoomListener)
    func roomListenerDidReceiveChat(roomListener: RoomListener, chat: Chat)
}

// MARK: main

class RoomListener : NSObject, NSStreamDelegate {
    let delegate: RoomListenerDelegate?
    let server: MessageServer?
    
    var inputStream: NSInputStream!
    var outputStream: NSOutputStream!
    
    let log = XCGLogger.defaultInstance()
    let fileLog = XCGLogger()
    
    init(delegate: RoomListenerDelegate?, server: MessageServer?) {
        super.init()
        
        self.delegate = delegate
        self.server = server
        
        log.info("listener initialized w/ server:" +
            "\(self.server?.roomPosition),\(self.server?.address),\(self.server?.port),\(self.server?.thread)")
        
        self.initializeFileLog()
    }
    
    func initializeFileLog() {
        var logNumber = 0
        if let server = self.server {
            logNumber = server.roomPosition.rawValue
        }
        
        let fileLogPath = NSHomeDirectory() + "/Hakumai_\(logNumber).log"
        fileLog.setup(logLevel: .Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: fileLogPath)
        
        if let console = fileLog.logDestination(XCGLogger.constants.baseConsoleLogDestinationIdentifier) {
            fileLog.removeLogDestination(console)
        }
        
        fileLog.debug("file log started.")
    }
    
    // MARK: - Socket Functions
    func openSocket() {
        let server = self.server!
        
        var input :NSInputStream?
        var output :NSOutputStream?
        
        NSStream.getStreamsToHostWithName(server.address, port: server.port, inputStream: &input, outputStream: &output)
        
        if input == nil || output == nil {
            fileLog.error("failed to open socket.")
            return
        }
        
        self.inputStream = input!
        self.outputStream = output!
        
        self.inputStream?.delegate = self
        self.outputStream?.delegate = self
        
        let loop = NSRunLoop.currentRunLoop()
        
        self.inputStream?.scheduleInRunLoop(loop, forMode: NSDefaultRunLoopMode)
        self.outputStream?.scheduleInRunLoop(loop, forMode: NSDefaultRunLoopMode)
        
        self.inputStream?.open()
        self.outputStream?.open()
        
        self.sendOpenThreadText(server.thread)
        
        loop.run()
    }
    
    func closeSocket() {
        fileLog.debug("closed streams.")
        
        self.inputStream?.close()
        self.outputStream?.close()
    }
    
    // MARK: -
    func sendOpenThreadText(thread: Int) {
        let buffer = "<thread thread=\"\(thread)\" version=\"20061206\" res_form=\"-1\"/>\0"
        let data: NSData = buffer.dataUsingEncoding(NSUTF8StringEncoding)!
        self.outputStream?.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
    }
    
    // MARK: NSStreamDelegate Functions
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            fileLog.debug("*** stream event none")
            
        case NSStreamEvent.OpenCompleted:
            fileLog.debug("*** stream event open completed");
            
        case NSStreamEvent.HasBytesAvailable:
            // fileLog.debug("*** stream event has bytes available");
            
            // http://stackoverflow.com/q/26360962
            var readByte = [UInt8](count: 10240, repeatedValue: 0)
            
            while self.inputStream.hasBytesAvailable {
                self.inputStream.read(&readByte, maxLength: 10240)
                //fileLog.debug(readByte)
            }
            
            if let readString = NSString(bytes: &readByte, length: readByte.count, encoding: NSUTF8StringEncoding) {
                // fileLog.debug(readString?)
                self.parseInputStream(readString)
            }
            
        case NSStreamEvent.HasSpaceAvailable:
            fileLog.debug("*** stream event has space available");
            
        case NSStreamEvent.ErrorOccurred:
            fileLog.error("*** stream event error occurred");
            self.closeSocket();
            
        case NSStreamEvent.EndEncountered:
            fileLog.debug("*** stream event end encountered");
            
        default:
            fileLog.warning("*** unexpected stream event...");
        }
    }
    
    func parseInputStream(stream: String) {
        let delegate = self.delegate!
        
        let wrappedStream = "<items>" + stream + "</items>"
        fileLog.verbose("[ " + wrappedStream + " ]")
        
        var err: NSError?
        let xmlDocument = NSXMLDocument(XMLString: wrappedStream, options: Int(NSXMLDocumentTidyXML), error: &err)
        
        if xmlDocument == nil {
            fileLog.error("could not parse input stream:\(stream)")
            return
        }
        
        if let rootElement = xmlDocument?.rootElement() {
            // rootElement = '<items>...</item>'

            let threads = self.parseThreadElement(rootElement)
            for thread in threads {
                delegate.roomListenerDidStartListening(self)
            }
        
            let chats = self.parseChatElement(rootElement)
            for chat in chats {
                delegate.roomListenerDidReceiveChat(self, chat: chat)
            }
        }
    }
    
    func parseThreadElement(rootElement: NSXMLElement) -> [Thread] {
        var threadArray: Array<Thread> = []
        let threadElements = rootElement.elementsForName("thread")
        
        for threadElement in threadElements {
            let thread = Thread()
            
            thread.resultCode = threadElement.attributeForName("resultcode")?.stringValue?.toInt()
            
            threadArray.append(thread)
        }
        
        return threadArray
    }
    
    func parseChatElement(rootElement: NSXMLElement) -> [Chat] {
        var chatArray: Array<Chat> = []
        let chatElements = rootElement.elementsForName("chat")
        
        for chatElement in chatElements {
            let chat = Chat()

            chat.roomPosition = self.server?.roomPosition
            
            if let date = chatElement.attributeForName("date")?.stringValue?.toInt() {
                chat.date = NSDate(timeIntervalSince1970: Double(date))
            }
            
            if let premium = chatElement.attributeForName("premium")?.stringValue?.toInt() {
                chat.premium = Premium(rawValue: premium)
            }
            else {
                // assume no attribute provided as Ippan(0)
                chat.premium = Premium(rawValue: 0)
            }
            
            chat.mail = chatElement.attributeForName("mail")?.stringValue
            chat.userId = chatElement.attributeForName("user_id")?.stringValue
            chat.score = 123
            chat.comment = chatElement.stringValue
            
            chatArray.append(chat)
        }
        
        return chatArray
    }
}
