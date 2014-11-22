//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// MARK: protocol

protocol NicoUtilityProtocol {
    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition)
    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat)
    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat)
    func nicoUtilityDidFinishListening(nicoUtility: NicoUtility)
}

// MARK: constant value

let kRequiredCommunityLevelForStandRoom: [RoomPosition: Int] = [
    .Arena: 0,
    .StandA: 0,
    .StandB: 66,
    .StandC: 70,
    .StandD: 105,
    .StandE: 150,
    .StandF: 190,
    .StandG: 232]

let kGetPlayerStatuUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus?v=lv"
let kGetPostKeyUrl = "http://live.nicovideo.jp/api/getpostkey?thread=%d&block_no=%d"
let kCommunityUrl = "http://com.nicovideo.jp/community/"

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
    
    var stream: Stream?
    var user: User?
    var messageServer: MessageServer?
    
    var messageServers: [MessageServer] = []
    var roomListeners: [RoomListener] = []
    var receivedFirstChat = [RoomPosition: Bool]()
    
    let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    private override init() {
        super.init()
    }
    
    class func sharedInstance() -> NicoUtility {
        return nicoutility
    }

    // MARK: - Public Interface
    func connect(live: Int) {
        if 0 < self.roomListeners.count {
            self.disconnect()
        }
        
        func completion(stream: Stream?, user: User?, server: MessageServer?) {
            self.log.debug("extracted stream: \(stream)")
            self.log.debug("extracted server: \(server)")
            
            if stream == nil || server == nil {
                self.log.error("could not extract live information.")
                return
            }
            
            self.stream = stream
            self.user = user
            self.messageServer = server
            
            self.checkCommunityLevel(self.stream!.community.community!, completion: { (communityLevel) -> Void in
                self.log.debug("checked community level: \(communityLevel)")
                self.stream?.community.level = communityLevel
                self.openMessageServers(server!)
            })
        }
        
        self.getPlayerStatus(live, completion: completion)
    }
    
    func disconnect() {
        for listener in self.roomListeners {
            listener.closeSocket()
        }
        
        self.roomListeners.removeAll(keepCapacity: false)
        self.receivedFirstChat.removeAll(keepCapacity: false)
        
        if let delegate = self.delegate {
            dispatch_async(dispatch_get_main_queue(), {
                delegate.nicoUtilityDidFinishListening(self)
            })
        }
    }
    
    func comment(comment: String) {
        self.getPostKey { (postKey) -> (Void) in
            if self.stream == nil || self.user == nil || postKey == nil {
                self.log.debug("no available stream, user, or post key")
                return
            }
            
            let roomListener = self.roomListeners[self.messageServer!.roomPosition.rawValue]
            roomListener.comment(self.stream!, user: self.user!, postKey: postKey!, comment: comment)
        }
    }
    
    // MARK: - Message Server Functions
    func openMessageServers(originServer: MessageServer) {
        self.messageServers = self.deriveMessageServers(originServer)
        
        // opens arena only
        self.addMessageServer()
    }
    
    func addMessageServer() {
        if self.roomListeners.count == self.messageServers.count {
            log.info("already opened max servers.")
            return
        }
        
        if let lastRoomListener = self.roomListeners.last {
            if let lastRoomPosition = lastRoomListener.server?.roomPosition {
                if let level = self.stream?.community.level {
                    if !self.canOpenRoomPosition(lastRoomPosition.next()!, communityLevel: level) {
                        log.info("already opened max servers with this community level \(level)")
                        return
                    }
                }
            }
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
    
    func canOpenRoomPosition(roomPosition: RoomPosition, communityLevel: Int) -> Bool {
        let requiredCommunityLevel = kRequiredCommunityLevelForStandRoom[roomPosition]
        return (requiredCommunityLevel <= communityLevel)
    }
    
    func getPlayerStatus(live: Int, completion: (stream: Stream?, user: User?, messageServer: MessageServer?) -> (Void)) {
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in cookied async request")
                completion(stream: nil, user: nil, messageServer: nil)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            log.debug("\(responseString)")
            
            if data == nil {
                log.error("error in unpacking response data")
                completion(stream: nil, user: nil, messageServer: nil)
                return
            }
            
            if self.isErrorResponse(data) {
                log.error("detected error")
                completion(stream: nil, user: nil, messageServer: nil)
                return
            }
            
            let stream = self.extractStream(data)
            let user = self.extractUser(data)
            let messageServer = self.extractMessageServer(data)
            
            if stream == nil || user == nil || messageServer == nil {
                log.error("error in extracting getplayerstatus response")
                completion(stream: nil, user: nil, messageServer: nil)
                return
            }

            completion(stream: stream, user: user, messageServer: messageServer)
        }

        self.cookiedAsyncRequest(kGetPlayerStatuUrl + String(live), completion: httpCompletion)
    }
    
    // MARK: - General Extractor
    func isErrorResponse(xmlData: NSData) -> Bool {
        var err: NSError?
        
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let status = rootElement?.attributeForName("status")?.stringValue
        
        if status == "fail" {
            log.warning("failed to load message server")
            
            if let errorCode = (rootElement?.nodesForXPath("/getplayerstatus/error/code", error: &err)?[0] as NSXMLNode).stringValue {
                log.warning("error code: \(errorCode)")
            }
            
            return true
        }
        
        return false
    }
    
    // MARK: - Stream Extractor
    func extractStream(xmlData: NSData) -> Stream? {
        var err: NSError?
        
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let stream = Stream()
        
        stream.baseTime = (rootElement?.nodesForXPath("/getplayerstatus/stream/base_time", error: &err)?[0] as NSXMLNode).stringValue?.toInt()
        
        stream.community.community = (rootElement?.nodesForXPath("/getplayerstatus/stream/default_community", error: &err)?[0] as NSXMLNode).stringValue
        return stream
    }
    
    func checkCommunityLevel(community: String, completion: ((Int?) -> Void)) {
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in cookied async request")
                completion(nil)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // log.debug("\(responseString)")
            
            if data == nil {
                log.error("error in unpacking response data")
                completion(nil)
                return
            }
            
            // extract community level here
            let level = self.extractCommunityLevel(data)
            
            if level == nil {
                log.error("error in extracting community level")
                completion(nil)
                return
            }
            
            completion(level)
        }
        
        self.cookiedAsyncRequest(kCommunityUrl + community, completion: httpCompletion)
    }
    
    func extractCommunityLevel(xmlData: NSData) -> Int? {
        var err: NSError?
        let xmlDocument = NSXMLDocument(data: xmlData, options: Int(NSXMLDocumentTidyXML), error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let xpath = "//*[@id=\"cbox_profile\"]/table/tr/td[1]/table/tr[1]/td[2]/strong[1]"
        
        if let nodes = rootElement?.nodesForXPath(xpath, error: &err) {
            if 0 < nodes.count {
                return (nodes[0] as NSXMLNode).stringValue?.toInt()
            }
        }
        
        return nil
    }
    
    // MARK: - Message Server Extractor
    func extractMessageServer (xmlData: NSData) -> MessageServer? {
        var err: NSError?
        
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let status = rootElement?.attributeForName("status")?.stringValue
        
        if status == "fail" {
            log.warning("failed to load message server")
            
            if let errorCode = (rootElement?.nodesForXPath("/getplayerstatus/error/code", error: &err)?[0] as NSXMLNode).stringValue {
                log.warning("error code: \(errorCode)")
            }
            
            return nil
        }

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
    
    // MARK: - User Extractor
    func extractUser(xmlData: NSData) -> User? {
        var err: NSError?
        
        let xmlDocument = NSXMLDocument(data: xmlData, options: kNilOptions, error: &err)
        let rootElement = xmlDocument?.rootElement()
        
        let user = User()
        
        user.userId = (rootElement?.nodesForXPath("/getplayerstatus/user/user_id", error: &err)?[0] as NSXMLNode).stringValue?.toInt()
        user.nickname = (rootElement?.nodesForXPath("/getplayerstatus/user/nickname", error: &err)?[0] as NSXMLNode).stringValue
        
        return user
    }
    
    // MARK: - Comment
    func getPostKey(completion: (postKey: String?) -> (Void)) {
        if messageServer == nil {
            log.error("cannot comment without messageServer")
            completion(postKey: nil)
            return
        }
        
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in cookied async request")
                completion(postKey: nil)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            log.debug("\(responseString)")
            
            if data == nil {
                log.error("error in unpacking response data")
                completion(postKey: nil)
                return
            }
            
            let postKey = (responseString as String).extractRegexpPattern("postkey=(.+)")
            
            if postKey == nil {
                log.error("error in extracting postkey")
                completion(postKey: nil)
                return
            }
            
            completion(postKey: postKey)
        }
        
        let thread = messageServer!.thread
        let blockNo = (roomListeners[messageServer!.roomPosition.rawValue].lastRes + 1) / 100
        
        let getPostKeyUrl = String(format: kGetPostKeyUrl, thread, blockNo)
        self.cookiedAsyncRequest(getPostKeyUrl, completion: httpCompletion)
    }
    
    // MARK: - General Utility
    func cookiedAsyncRequest(urlString: String, completion: (NSURLResponse!, NSData!, NSError!) -> Void) {
        let url = NSURL(string: urlString)!
        var request = NSMutableURLRequest(URL: url)
        
        if let cookie = self.sessionCookie() {
            let requestHeader = NSHTTPCookie.requestHeaderFieldsWithCookies([cookie])
            request.allHTTPHeaderFields = requestHeader
        }
        else {
            log.error("could not get cookie")
            completion(nil, nil, NSError(domain:"", code:0, userInfo: nil))
        }
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: completion)
    }
    
    func sessionCookie() -> NSHTTPCookie? {
        if let cookie = CookieUtility.cookie(CookieUtility.BrowserType.Chrome) {
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
    
    // MARK: - RoomListenerDelegate Functions
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

        // open next room, if first comment in the room received
        if chat.premium == .Ippan || chat.premium == .Premium {
            if let room = roomListener.server?.roomPosition {
                if self.receivedFirstChat[room] == nil || self.receivedFirstChat[room] == false {
                    self.receivedFirstChat[room] = true
                    
                    if let delegate = self.delegate {
                        dispatch_async(dispatch_get_main_queue(), {
                            delegate.nicoUtilityDidReceiveFirstChat(self, chat: chat)
                        })
                    }

                    self.addMessageServer()
                }
            }
        }
    }
}