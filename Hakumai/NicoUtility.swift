//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// MARK: type

typealias getPlayerStatusCompletion = (messageServer: MessageServer?) -> (Void)

// MARK: protocol

protocol NicoUtilityProtocol {
    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition)
    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat)
}

// MARK: constant value

let kGetPlayerStatuUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus?v=lv"

// MARK: global value

private let nicoutility = NicoUtility()

// MARK: extension

// enabling operation like followings;
// (("C" as Character) - ("A" as Character)) + 1 -> 3 (means "Stand-C")
// based on http://stackoverflow.com/a/24102584
extension Character {
    func unicodeScalarCodePoint() -> UInt32 {
        let characterString = String(self)
        let scalars = characterString.unicodeScalars
        
        return scalars[scalars.startIndex].value
    }
}

// MARK: operator overload

func -(left: Character, right: Character) -> Int {
    return left.unicodeScalarCodePoint() - right.unicodeScalarCodePoint()
}

// MARK: class

class NicoUtility : NSObject, RoomListenerDelegate {
    var delegate: NicoUtilityProtocol?
    
    var messageServers: [MessageServer] = []
    var roomListeners: [RoomListener] = []
    
    let log = XCGLogger.defaultInstance()
    
    private override init() {
        super.init()
    }
    
    class func getInstance() -> NicoUtility {
        return nicoutility
    }

    // MARK: public interface
    func connect(live: Int) {
        if 0 < self.roomListeners.count {
            self.disconnect()
        }
        
        self.getPlayerStatus (live, {(server: MessageServer?) -> (Void) in
            self.log.debug("\(server)")
            
            if server == nil {
                self.log.error("could not obtain message server.")
                return
            }
            
            self.openMessageServers(server!)
        })
    }
    
    func addMessageServer() {
        if self.roomListeners.count == self.messageServers.count {
            log.info("already opened max servers.")
            return
        }
        
        let targetServerIndex = self.roomListeners.count
        let targetServer = self.messageServers[targetServerIndex]
        let listener = RoomListener(delegate: self, server: targetServer)
        
        let qualityOfServiceClass = Int(QOS_CLASS_BACKGROUND.value)
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            listener.openSocket()
        })
        
        self.roomListeners.append(listener)
    }
    
    func disconnect() {
        for listener in self.roomListeners {
            listener.closeSocket()
        }
        
        self.roomListeners.removeAll(keepCapacity: false)
    }
    
    // MARK: -
    func openMessageServers(originServer: MessageServer) {
        self.messageServers = self.deriveMessageServers(originServer)

        for i in 1...2 {
            self.addMessageServer()
        }
    }
    
    func getPlayerStatus(live: Int, completion: getPlayerStatusCompletion) {
        let url = NSURL(string: kGetPlayerStatuUrl + String(live))!
        var request = NSMutableURLRequest(URL: url)
        
        if let cookie = self.sessionCookie() {
            let requestHeader = NSHTTPCookie.requestHeaderFieldsWithCookies([cookie])
            request.allHTTPHeaderFields = requestHeader
        }
        else {
            log.error("could not get cookie")
            completion(messageServer: nil)
        }
        
        func completionHandler (response: NSURLResponse?, data: NSData?, connectionError: NSError?) {
            let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
            log.debug("\(responseString)")
            
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
            log.debug("cookie:[\(cookie)]")
            
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
    
    func extractMessageServer (xmlData: NSData) -> MessageServer? {
        var err: NSError?
        
        // let xmlDocument = NSXMLDocument(data: xmlData, options: [NSXMLDocumentTidyXML], error: err!)
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let roomLabel = (rootElement?.nodesForXPath("/getplayerstatus/user/room_label", error: &err)?[0] as NSXMLNode).stringValue
        
        if roomLabel == nil {
            return nil
        }
        
        let roomPosition = self.roomPositionByRoomLabel(roomLabel!)
        
        if roomPosition == nil {
            return nil
        }
        
        let address = (rootElement?.nodesForXPath("/getplayerstatus/ms/addr", error: &err)?[0] as NSXMLNode).stringValue
        let port = (rootElement?.nodesForXPath("/getplayerstatus/ms/port", error: &err)?[0] as NSXMLNode).stringValue?.toInt()
        let thread = (rootElement?.nodesForXPath("/getplayerstatus/ms/thread", error: &err)?[0] as NSXMLNode).stringValue?.toInt()
        // log.debug("\(address?),\(port),\(thread)")
 
        if address == nil || port == nil || thread == nil {
            return nil
        }

        let server = MessageServer(roomPosition: roomPosition!, address: address!, port: port!, thread: thread!)
        
        return server
    }
    
    func roomPositionByRoomLabel(roomLabel: String) -> RoomPosition? {
        // log.debug("roomLabel:\(roomLabel)")
        
        if self.isArena(roomLabel) == true {
            return RoomPosition(rawValue: 0)
        }
        
        if let standCharacter = self.extractStandCharacter(roomLabel) {
            log.debug("extracted standCharacter:\(standCharacter)")
            let raw = (standCharacter - ("A" as Character)) + 1
            return RoomPosition(rawValue: raw)
        }
        
        return nil
    }
    
    func isArena(roomLabel: String) -> Bool {
        let regexp = NSRegularExpression(pattern: "co\\d+", options: nil, error: nil)!
        let matched = regexp.firstMatchInString(roomLabel, options: nil, range: NSMakeRange(0, roomLabel.utf16Count))
        
        return matched != nil ? true : false
    }
    
    func extractStandCharacter(roomLabel: String) -> Character? {
        let matched = roomLabel.extractRegexpPattern("立ち見(\\w)列")
        
        // using subscript String extension defined above
        return matched?[0]
    }

    // MARK: Message Server Utility
    func deriveMessageServers(originServer: MessageServer) -> [MessageServer] {
        if originServer.isOfficial() == true {
            // TODO: not yet supported
            return [originServer]
        }
        
        var arenaServer = originServer
        
        if 0 < originServer.roomPosition.rawValue {
            for _ in 1...(originServer.roomPosition.rawValue) {
                arenaServer = arenaServer.previous()
            }
        }
        
        var servers = [arenaServer]
        
        // add stand a, b, c, d, e, f
        for _ in 1...6 {
            servers.append(servers.last!.next())
        }
        
        return servers
    }
    
    func deriveMessageServer(originServer: MessageServer, distance: Int) -> MessageServer? {
        if originServer.isOfficial() == true {
            // TODO: not yet supported
            return nil
        }
        
        if distance == 0 {
            return originServer
        }
        
        var server = originServer
        
        if 0 < distance {
            for _ in 1...distance {
                server = server.next()
            }
        }
        else {
            for _ in 1...abs(distance) {
                server = server.previous()
            }
        }
        
        return server
    }
    
    // MARK: RoomListenerDelegate Functions
    func roomListenerDidStartListening(roomListener: RoomListener) {
        if let delegate = self.delegate {
            dispatch_async(dispatch_get_main_queue(), {
                delegate.nicoUtilityDidStartListening(self, roomPosition: roomListener.server!.roomPosition)
            })
        }
    }
    
    func roomListenerDidReceiveChat(roomListener: RoomListener, chat: Chat) {
        if let delegate = self.delegate {
            dispatch_async(dispatch_get_main_queue(), {
                delegate.nicoUtilityDidReceiveChat(self, chat: chat)
            })
        }
    }
}