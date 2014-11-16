//
//  RoomListener.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/16/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: struct

struct Chat {
    let roomPosition: Int?
    let mail: String?
    let userId: String
    let comment: String
    let score: Int
}

// MARK: protocol

protocol RoomListenerDelegate {
    func roomListenerReceivedChat(roomListener: RoomListener, chat: Chat)
}

// MARK: main

class RoomListener : NSObject, NSStreamDelegate {
    let delegate: RoomListenerDelegate?
    let server: messageServer?
    
    var inputStream: NSInputStream!
    var outputStream: NSOutputStream!
    
    init(delegate: RoomListenerDelegate?, server: messageServer?) {
        self.delegate = delegate
        self.server = server
        
        println("listener initialized w/ server:" +
            "\(self.server?.roomPosition),\(self.server?.address),\(self.server?.port),\(self.server?.thread)")
        
        super.init()
    }
    
    // MARK: - Socket Functions
    func openSocket() {
        let server = self.server!
        
        var input :NSInputStream?
        var output :NSOutputStream?
        
        NSStream.getStreamsToHostWithName(server.address, port: server.port, inputStream: &input, outputStream: &output)
        
        if input == nil || output == nil {
            println("failed to open socket.")
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
        println("closed streams.")
        
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
            println("*** stream event none")
            
        case NSStreamEvent.OpenCompleted:
            println("*** stream event open completed");
            
        case NSStreamEvent.HasBytesAvailable:
            // println("*** stream event has bytes available");
            
            // http://stackoverflow.com/q/26360962
            var readByte = [UInt8](count: 10240, repeatedValue: 0)
            
            while self.inputStream.hasBytesAvailable {
                self.inputStream.read(&readByte, maxLength: 10240)
                //println(readByte)
            }
            
            if let readString = NSString(bytes: &readByte, length: readByte.count, encoding: NSUTF8StringEncoding) {
                // println(readString?)
                if let chats = self.parseChat(readString) {
                    for chat in chats {
                        // println("\(chat.score),\(chat.comment)")
                        
                        dispatch_async(dispatch_get_main_queue(), {
                            if let delegate = self.delegate {
                                delegate.roomListenerReceivedChat(self, chat: chat)
                            }
                        })
                    }
                }
            }
            
        case NSStreamEvent.HasSpaceAvailable:
            println("*** stream event has space available");
            
        case NSStreamEvent.ErrorOccurred:
            println("*** stream event error occurred");
            // [self closeSocket];
            
        case NSStreamEvent.EndEncountered:
            println("*** stream event end encountered");
            
        default:
            println("*** unexpected stream event...");
        }
    }
    
    func parseChat(chat: String) -> [Chat]? {
        var err: NSError?
        
        let chats = "<chats>" + chat + "</chats>"
        // println("wrapped chat: >>> " + chat + " <<<")
        
        let xmlDocument = NSXMLDocument(XMLString: chats, options: Int(NSXMLDocumentTidyXML), error: &err)
        
        if xmlDocument == nil {
            println("could not parse chat:\(chat)")
            return nil
        }
        
        let chatsElement = xmlDocument?.rootElement()
        
        if chatsElement == nil || chatsElement?.name != "chats" {
            println("could not find chat:\(chats)")
            return nil
        }
        
        let chatElements = chatsElement!.elementsForName("chat")
        var chatsArray: [Chat] = []
        
        for chatElement in chatElements {
            let comment = chatElement.stringValue
            let mail = chatElement.attributeForName("mail")?.stringValue
            let userId = chatElement.attributeForName("user_id")?.stringValue
            
            let chatStruct = Chat(roomPosition: self.server?.roomPosition, mail: mail, userId: userId!, comment: comment!, score: 123)
            chatsArray.append(chatStruct)
        }
        
        return chatsArray
    }
}
