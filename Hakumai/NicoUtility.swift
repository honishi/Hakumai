//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: struct

struct messageServer {
    let roomPosition: Int
    let address: String
    let port: Int
    let thread: Int
}

struct Chat {
    let mail: String?
    let userId: String
    let comment: String
    let score: Int
}

// MARK: type

typealias getPlayerStatusCompletion = (messageServer: messageServer?) -> (Void)

// MARK: protocol

protocol NicoUtilityProtocol {
    func receiveChat(nicoUtility: NicoUtility, chat: Chat)
}

// MARK: constant value

let kGetPlayerStatuUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus?v=lv"

// MARK: global value

private let nicoutility = NicoUtility()

// MARK: class

class NicoUtility : NSObject, NSStreamDelegate {

    var delegate: NicoUtilityProtocol?
    
    var inputStream: NSInputStream!
    var outputStream: NSOutputStream!
    
    private override init() {
        super.init()
    }
    
    class func getInstance() -> NicoUtility {
        return nicoutility
    }

    // MARK: public interface
    func connect() {
        self.getPlayerStatus ({(messageServer: messageServer?) -> (Void) in
            println(messageServer)
            
            if messageServer == nil {
                println("could not obtain message server.")
                return
            }
            
            self.openMessageServer(messageServer!.address, port: messageServer!.port)
            self.sendOpenThreadText(messageServer!.thread)
        })
    }
    
    // MARK: -
    func getPlayerStatus(completion: getPlayerStatusCompletion) {
        let url = NSURL(string: kGetPlayerStatuUrl + "200020498")!
        var request = NSMutableURLRequest(URL: url)
        
        if let cookie = self.sessionCookie() {
            let requestHeader = NSHTTPCookie.requestHeaderFieldsWithCookies([cookie])
            request.allHTTPHeaderFields = requestHeader
        }
        else {
            println("could not get cookie")
            completion(messageServer: nil)
        }
        
        func completionHandler (response: NSURLResponse?, data: NSData?, connectionError: NSError?) {
            let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
            println(responseString)
            
            if data == nil {
                return
            }
            
            let messageServer = self.extractMessageServer(data!)
            
            if messageServer == nil {
                completion(messageServer: nil)
                return
            }

            completion(messageServer: messageServer)
        }
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: completionHandler)
    }
    
    func sessionCookie() -> NSHTTPCookie? {
        if let cookie = CookieUtility.chromeCookie() {
            println("cookie:[\(cookie)]")
            
            let userSessionCookie = NSHTTPCookie(properties: [
                NSHTTPCookieDomain: "nicovideo.jp",
                NSHTTPCookieName: "user_session",
                NSHTTPCookieValue: cookie,
                NSHTTPCookieExpires: NSDate().dateByAddingTimeInterval(7200),
                NSHTTPCookiePath: "/"])
            
            return userSessionCookie
        }
        
        return nil
    }
    
    func extractMessageServer (xmlData: NSData) -> messageServer? {
        var err: NSError?
        
        // let xmlDocument = NSXMLDocument(data: xmlData, options: [NSXMLDocumentTidyXML], error: err!)
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let address = (rootElement?.nodesForXPath("/getplayerstatus/ms/addr", error: &err)?[0] as NSXMLNode).stringValue
        let port = (rootElement?.nodesForXPath("/getplayerstatus/ms/port", error: &err)?[0] as NSXMLNode).stringValue?.toInt()
        let thread = (rootElement?.nodesForXPath("/getplayerstatus/ms/thread", error: &err)?[0] as NSXMLNode).stringValue?.toInt()
        
        println("\(address?),\(port),\(thread)")
 
        if address == nil || port == nil || thread == nil {
            return nil
        }

        let server = messageServer(roomPosition: 0, address: address!, port: port!, thread: thread!)
        
        return server
    }
    
    // MARK: 
    func openMessageServer(address: String, port: Int) {
        // var host :NSHost = NSHost(address: address)
        var input :NSInputStream?
        var output :NSOutputStream?
        
        NSStream.getStreamsToHostWithName(address, port: port, inputStream: &input, outputStream: &output)

        if input == nil || output == nil {
            println("failed to open socket.")
            return
        }
        
        self.inputStream = input!
        self.outputStream = output!
        
        self.inputStream?.delegate = self
        self.outputStream?.delegate = self
        
        self.inputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.outputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        
        self.inputStream?.open()
        self.outputStream?.open()
    }
    
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
            var readByte = [UInt8](count: 500, repeatedValue: 0)
            
            while self.inputStream.hasBytesAvailable {
                self.inputStream.read(&readByte, maxLength: 500)
                //println(readByte)
            }
            
            var output = NSString(bytes: &readByte, length: readByte.count, encoding: NSUTF8StringEncoding)
            // println(output?)

            if let chat = output {
                if let s = self.parseChat(chat) {
                    // println("\(s?.score),\(s?.comment)")
                    if let d = self.delegate {
                        d.receiveChat(self, chat: s)
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
    
    func parseChat(chat: String) -> Chat? {
        var err: NSError?
        
        let xmlDocument = NSXMLDocument(XMLString: chat, options: Int(NSXMLDocumentTidyXML), error: &err)
        
        if xmlDocument == nil {
            println("could not parse chat:\(chat)")
            return nil
        }
        
        let chatElement = xmlDocument?.rootElement()
        
        if chatElement == nil || chatElement?.name != "chat" {
            println("could not find chat:\(chat)")
            return nil
        }
        
        println(chat)
        
        let comment = chatElement?.stringValue
        let mail = chatElement?.attributeForName("mail")?.stringValue
        let userId = chatElement?.attributeForName("user_id")?.stringValue

        let chatStruct = Chat(mail: mail, userId: userId!, comment: comment!, score: 123)
        
        return chatStruct
    }
}