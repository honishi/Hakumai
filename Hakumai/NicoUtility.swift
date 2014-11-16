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
    let official: Bool
    let roomPosition: Int
    let address: String
    let port: Int
    let thread: Int
}

// MARK: operator overload

// this overload is used in test methods
func == (left: messageServer, right: messageServer) -> Bool {
    return (left.official == right.official &&
            left.roomPosition == right.roomPosition &&
            left.address == right.address &&
            left.port == right.port &&
            left.thread == right.thread)
}

func != (left: messageServer, right: messageServer) -> Bool {
    return !(left == right)
}

func == (left: Array<messageServer>, right: Array<messageServer>) -> Bool {
    if left.count != right.count {
        return false
    }
    
    for i in 0..<left.count {
        if left[i] != right[i] {
            return false
        }
    }
    
    return true
}

// MARK: type

typealias getPlayerStatusCompletion = (messageServer: messageServer?) -> (Void)

// MARK: protocol

protocol NicoUtilityProtocol {
    func nicoUtilityReceivedChat(nicoUtility: NicoUtility, chat: Chat)
}

// MARK: constant value

let kMessageServerNumberFirst = 101
let kMessageServerNumberLast = 104
let kMessageServerPortOfficialFirst = 2815
let kMessageServerPortOfficialLast = 2817
let kMessageServerPortUserFirst = 2805
let kMessageServerPortUserLast = 2814

let kMessageServerAddressHostPrefix = "msg"
let kMessageServerAddressDomain = ".live.nicovideo.jp"
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

// enabling intuitive operation to get nth Character from String
// based on http://stackoverflow.com/a/24144365
extension String {
    subscript (i: Int) -> Character {
        return Array(self)[i]
    }
    
    func extractRegexpPattern(pattern: String) -> String? {
        let regexp = NSRegularExpression(pattern: pattern, options: nil, error: nil)!
        let matched = regexp.firstMatchInString(self, options: nil, range: NSMakeRange(0, self.utf16Count))
        // println(matched)
        
        if matched == nil {
            return nil
        }
        
        let nsRange = matched?.rangeAtIndex(1)
        let start = advance(self.startIndex, nsRange!.location)
        let end = advance(self.startIndex, nsRange!.location + nsRange!.length)
        let range = Range<String.Index>(start: start, end: end)
        let substring = self.substringWithRange(range)
        
        return substring
    }
}

// MARK: operator overload

func -(left: Character, right: Character) -> Int {
    return left.unicodeScalarCodePoint() - right.unicodeScalarCodePoint()
}

// MARK: class

class NicoUtility : NSObject, RoomListenerDelegate {
    var delegate: NicoUtilityProtocol?
    
    var messageServers: [messageServer] = []
    var roomListeners: [RoomListener] = []
    
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
        
        self.getPlayerStatus (live, {(server: messageServer?) -> (Void) in
            println(server)
            
            if server == nil {
                println("could not obtain message server.")
                return
            }
            
            self.openMessageServers(server!)
        })
    }
    
    func addMessageServer() {
        if self.roomListeners.count == self.messageServers.count {
            println("already opened max servers.")
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
    func openMessageServers(originServer: messageServer) {
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
        // println("\(address?),\(port),\(thread)")
 
        if address == nil || port == nil || thread == nil {
            return nil
        }

        let server = messageServer(official: false, roomPosition: roomPosition!, address: address!, port: port!, thread: thread!)
        
        return server
    }
    
    func roomPositionByRoomLabel(roomLabel: String) -> Int? {
        // println("roomLabel:\(roomLabel)")
        
        if self.isArena(roomLabel) == true {
            return 0
        }
        
        if let standCharacter = self.extractStandCharacter(roomLabel) {
            println("extracted standCharacter:\(standCharacter)")
            return (standCharacter - ("A" as Character)) + 1
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
    func deriveMessageServers(originServer: messageServer) -> [messageServer] {
        if originServer.official == true {
            // TODO: not yet supported
            return [originServer]
        }
        
        var arenaServer = originServer
        
        if 0 < originServer.roomPosition {
            for _ in 1...(originServer.roomPosition) {
                arenaServer = self.previousMessageServer(arenaServer)
            }
        }
        
        var servers = [arenaServer]
        
        // add stand a, b, c, d, e, f
        for _ in 1...6 {
            servers.append(self.nextMessageServer(servers.last!))
        }
        
        return servers
    }
    
    func deriveMessageServer(originServer: messageServer, distance: Int) -> messageServer? {
        if originServer.official == true {
            // TODO: not yet supported
            return nil
        }
        
        if distance == 0 {
            return originServer
        }
        
        var server = originServer
        
        if 0 < distance {
            for _ in 1...distance {
                server = self.nextMessageServer(server)
            }
        }
        else {
            for _ in 1...abs(distance) {
                server = self.previousMessageServer(server)
            }
        }
        
        return server
    }
    
    func previousMessageServer(originMessageServer: messageServer) -> messageServer {
        let roomPosition = originMessageServer.roomPosition - 1
        var address = originMessageServer.address
        var port = originMessageServer.port
        let thread = originMessageServer.thread - 1
        
        if port == kMessageServerPortUserFirst {
            port = kMessageServerPortUserLast
            
            if let serverNumber = self.extractServerNumber(address) {
                if serverNumber == kMessageServerNumberFirst {
                    address = self.serverAddressWithServerNumber(kMessageServerNumberLast)
                }
                else {
                    address = self.serverAddressWithServerNumber(serverNumber - 1)
                }
            }
        }
        else {
            port -= 1
        }
        
        return messageServer(official: false, roomPosition: roomPosition, address: address, port: port, thread: thread)
    }

    func nextMessageServer(originMessageServer: messageServer) -> messageServer {
        let roomPosition = originMessageServer.roomPosition + 1
        var address = originMessageServer.address
        var port = originMessageServer.port
        let thread = originMessageServer.thread + 1
        
        if port == kMessageServerPortUserLast {
            port = kMessageServerPortUserFirst
            
            if let serverNumber = self.extractServerNumber(address) {
                if serverNumber == kMessageServerNumberLast {
                    address = self.serverAddressWithServerNumber(kMessageServerNumberFirst)
                }
                else {
                    address = self.serverAddressWithServerNumber(serverNumber + 1)
                }
            }
        }
        else {
            port += 1
        }
        
        return messageServer(official: false, roomPosition: roomPosition, address: address, port: port, thread: thread)
    }

    func extractServerNumber(address: String) -> Int? {
        let regexp = kMessageServerAddressHostPrefix + "(\\d+)" + kMessageServerAddressDomain
        let serverNumber = address.extractRegexpPattern(regexp)
        
        return serverNumber?.toInt()
    }
    
    func serverAddressWithServerNumber(serverNumber: Int) -> String {
        return kMessageServerAddressHostPrefix + String(serverNumber) + kMessageServerAddressDomain
    }
    
    // MARK: RoomListenerDelegate Functions
    func roomListenerReceivedChat(roomListener: RoomListener, chat: Chat) {
        self.delegate?.nicoUtilityReceivedChat(self, chat: chat)
    }
}