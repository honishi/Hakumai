//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// MARK: - protocol

// note these functions are called in background thread, not main thread.
// so use explicit main thread for updating ui in these callbacks.
protocol NicoUtilityDelegate {
    func nicoUtilityDidPrepareLive(nicoUtility: NicoUtility, user: User, live: Live)
    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition)
    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat)
    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat)
    func nicoUtilityDidFinishListening(nicoUtility: NicoUtility)
    func nicoUtilityDidReceiveHeartbeat(nicoUtility: NicoUtility, heartbeat: Heartbeat)
}

// MARK: constant value

private let kRequiredCommunityLevelForStandRoom: [RoomPosition: Int] = [
    .Arena: 0,
    .StandA: 0,
    .StandB: 66,
    .StandC: 70,
    .StandD: 105,
    .StandE: 150,
    .StandF: 190,
    .StandG: 232]

// urls for api
private let kGetPlayerStatusUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus"
private let kGetPostKeyUrl = "http://live.nicovideo.jp/api/getpostkey"
private let kHeartbeatUrl = "http://live.nicovideo.jp/api/heartbeat"
private let kNgScoringUrl:String = "http://watch.live.nicovideo.jp/api/ngscoring"

// urls for scraping
private let kCommunityUrl = "http://com.nicovideo.jp/community/"
private let kUserUrl = "http://www.nicovideo.jp/user/"

// intervals
private let kHeartbeatDefaultInterval: NSTimeInterval = 30

// MARK: - class

class NicoUtility : NSObject, RoomListenerDelegate {
    var delegate: NicoUtilityDelegate?
    
    var live: Live?
    private var user: User?
    private var messageServer: MessageServer?
    
    private var messageServers: [MessageServer] = []
    private var roomListeners: [RoomListener] = []
    private var receivedFirstChat = [RoomPosition: Bool]()
    
    var cachedUsernames = [String: String]()
    
    private var heartbeatTimer: NSTimer?
    
    // logger
    let log = XCGLogger.defaultInstance()
    let fileLog = XCGLogger()

    // MARK: - Object Lifecycle
    private override init() {
        super.init()
        
        self.initializeFileLog()
    }
    
    class var sharedInstance : NicoUtility {
        struct Static {
            static let instance : NicoUtility = NicoUtility()
        }
        return Static.instance
    }
    
    func initializeFileLog() {
        let fileLogPath = NSHomeDirectory() + "/Hakumai.log"
        fileLog.setup(logLevel: .Verbose, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: fileLogPath)
        
        if let console = fileLog.logDestination(XCGLogger.constants.baseConsoleLogDestinationIdentifier) {
            fileLog.removeLogDestination(console)
        }
    }

    // MARK: - Public Interface
    func connect(liveNumber: Int) {
        if 0 < self.roomListeners.count {
            self.disconnect()
        }
        
        func completion(live: Live?, user: User?, server: MessageServer?) {
            self.log.debug("extracted live: \(live)")
            self.log.debug("extracted server: \(server)")
            
            if live == nil || server == nil {
                self.log.error("could not extract live information.")
                return
            }
            
            self.live = live
            self.user = user
            self.messageServer = server
            
            self.loadCommunity(self.live!.community, completion: {(isSuccess) -> Void in
                self.log.debug("loaded community info: success?:\(isSuccess) community:\(self.live!.community)")
                
                if !isSuccess {
                    self.log.error("error in loading community info")
                    return
                }
                
                if self.user != nil && self.live != nil {
                    self.delegate?.nicoUtilityDidPrepareLive(self, user: self.user!, live: self.live!)
                }
                
                self.openMessageServers(server!)
                self.scheduleHeartbeatTimer(immediateFire: true)
            })
        }
        
        self.requestGetPlayerStatus(liveNumber, completion: completion)
    }
    
    func disconnect() {
        for listener in self.roomListeners {
            listener.closeSocket()
        }
        
        self.stopHeartbeatTimer()
        self.delegate?.nicoUtilityDidFinishListening(self)
        self.reset()
    }
    
    func comment(comment: String, anonymously: Bool = true) {
        self.requestGetPostKey {(postKey) -> Void in
            if self.live == nil || self.user == nil || postKey == nil {
                self.log.debug("no available stream, user, or post key")
                return
            }
            
            let roomListener = self.roomListeners[self.messageServer!.roomPosition.rawValue]
            roomListener.comment(self.live!, user: self.user!, postKey: postKey!, comment: comment, anonymously: anonymously)
        }
    }
    
    func loadThumbnail(completion: (imageData: NSData?) -> Void) {
        if self.live?.community.thumbnailUrl == nil {
            log.debug("no thumbnail url")
            completion(imageData: nil)
            return
        }
        
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in loading thumbnail request")
                completion(imageData: nil)
                return
            }
            
            completion(imageData: data)
        }
        
        self.cookiedAsyncRequest("GET", url: self.live!.community.thumbnailUrl!, parameters: nil, completion: httpCompletion)
    }
    
    func resolveUsername(userId: String, completion: (userName: String?) -> Void) {
        if !self.isRawUserId(userId) {
            completion(userName: nil)
            return
        }
        
        if let cachedUsername = self.cachedUsernames[userId] {
            completion(userName: cachedUsername)
            return
        }
        
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in resolving username")
                completion(userName: nil)
                return
            }
            
            let username = self.extractUsername(data)
            self.cachedUsernames[userId] = username
            
            completion(userName: username)
        }
        
        self.cookiedAsyncRequest("GET", url: kUserUrl + String(userId), parameters: nil, completion: httpCompletion)
    }
    
    func reportAsNgUser(chat: Chat) {
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in requesting ng user")
                // TODO: error completion?
                return
            }
            
            log.debug("completed to request ng user")
            
            // TODO: success completion?
        }
        
        let parameters: [String: Any] = [
            "vid": self.live!.liveId!,
            "lang": "ja-jp",
            "type": "ID",
            "locale": "GLOBAL",
            "value": chat.userId!,
            "player": "v4",
            "uid": chat.userId!,
            "tpos": String(Int(chat.date!.timeIntervalSince1970)) + "." + String(chat.dateUsec!),
            "comment": String(chat.no!),
            "thread": String(self.messageServers[chat.roomPosition!.rawValue].thread),
            "comment_locale": "ja-jp"
        ]
        
        self.cookiedAsyncRequest("POST", url: kNgScoringUrl, parameters: parameters, completion: httpCompletion)
    }
    
    func urlStringForUserId(userId: String) -> String {
        return kUserUrl + userId
    }
    
    // MARK: - RoomListenerDelegate Functions
    func roomListenerDidReceiveThread(roomListener: RoomListener, thread: Thread) {
        log.debug("\(thread)")
        self.delegate?.nicoUtilityDidStartListening(self, roomPosition: roomListener.server!.roomPosition)
    }
    
    func roomListenerDidReceiveChat(roomListener: RoomListener, chat: Chat) {
        // open next room, if first comment in the room received
        if chat.premium == .Ippan || chat.premium == .Premium {
            if let room = roomListener.server?.roomPosition {
                if self.receivedFirstChat[room] == nil || self.receivedFirstChat[room] == false {
                    self.receivedFirstChat[room] = true
                    self.addMessageServer()
                    
                    self.delegate?.nicoUtilityDidReceiveFirstChat(self, chat: chat)
                }
            }
        }
        
        self.delegate?.nicoUtilityDidReceiveChat(self, chat: chat)
        
        if (chat.comment == "/disconnect" && (chat.premium == .Caster || chat.premium == .System) &&
            chat.roomPosition == .Arena) {
                self.disconnect()
        }
    }
    
    // MARK: - Internal Functions
    // MARK: Get Player Status
    private func requestGetPlayerStatus(liveNumber: Int, completion: (live: Live?, user: User?, messageServer: MessageServer?) -> Void) {
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in cookied async request")
                completion(live: nil, user: nil, messageServer: nil)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // log.debug("\(responseString)")
            
            if data == nil {
                log.error("error in unpacking response data")
                completion(live: nil, user: nil, messageServer: nil)
                return
            }
            
            if self.isErrorResponse(data) {
                log.error("detected error")
                completion(live: nil, user: nil, messageServer: nil)
                return
            }
            
            let live = self.extractLive(data)
            let user = self.extractUser(data)
            
            var messageServer: MessageServer?
            if user != nil {
                messageServer = self.extractMessageServer(data, user: user!)
            }
            
            if live == nil || user == nil || messageServer == nil {
                log.error("error in extracting getplayerstatus response")
                completion(live: nil, user: nil, messageServer: nil)
                return
            }
            
            completion(live: live, user: user, messageServer: messageServer)
        }
        
        self.cookiedAsyncRequest("GET", url: kGetPlayerStatusUrl, parameters: ["v": "lv" + String(liveNumber)], completion: httpCompletion)
    }
    
    // MARK: Community
    private func loadCommunity(community: Community, completion: ((Bool) -> Void)) {
        func httpCompletion (response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in cookied async request")
                completion(false)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // log.debug("\(responseString)")
            
            if data == nil {
                log.error("error in unpacking response data")
                completion(false)
                return
            }
            
            self.extractCommunity(data, community: community)
            
            completion(true)
        }
        
        self.cookiedAsyncRequest("GET", url: kCommunityUrl + community.community!, parameters: nil, completion: httpCompletion)
    }
    
    // MARK: Message Server Functions
    private func openMessageServers(originServer: MessageServer) {
        self.messageServers = self.deriveMessageServers(originServer)
        
        // opens arena only
        self.addMessageServer()
    }
    
    private func addMessageServer() {
        if self.roomListeners.count == self.messageServers.count {
            log.info("already opened max servers.")
            return
        }
        
        if let lastRoomListener = self.roomListeners.last {
            if let lastRoomPosition = lastRoomListener.server?.roomPosition {
                if let level = self.live?.community.level {
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
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
            listener.openSocket()
        })
        
        self.roomListeners.append(listener)
    }
    
    func canOpenRoomPosition(roomPosition: RoomPosition, communityLevel: Int) -> Bool {
        let requiredCommunityLevel = kRequiredCommunityLevelForStandRoom[roomPosition]
        return (requiredCommunityLevel <= communityLevel)
    }

    // MARK: (Message Server Utility)
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
    
    // MARK: Comment
    private func requestGetPostKey(completion: (postKey: String?) -> Void) {
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
        
        self.cookiedAsyncRequest("GET", url: kGetPostKeyUrl, parameters: ["thread": thread, "block_no": blockNo], completion: httpCompletion)
    }
    
    // MARK: Heartbeat
    private func scheduleHeartbeatTimer(immediateFire: Bool = false, interval: NSTimeInterval = kHeartbeatDefaultInterval) {
        self.stopHeartbeatTimer()
        
        dispatch_async(dispatch_get_main_queue(), {
            self.heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: "checkHeartbeat:", userInfo: nil, repeats: true)
            if immediateFire {
                self.heartbeatTimer?.fire()
            }
        })
    }
    
    private func stopHeartbeatTimer() {
        if self.heartbeatTimer == nil {
            return
        }
        
        self.heartbeatTimer?.invalidate()
        self.heartbeatTimer = nil
    }
    
    func checkHeartbeat(timer: NSTimer) {
        func httpCompletion(response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in checking heartbeat")
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            fileLog.debug("\(responseString)")
            
            let heartbeat = self.extractHeartbeat(data)
            fileLog.debug("\(heartbeat)")
            
            if heartbeat == nil {
                log.error("error in extracting heatbeat")
                return
            }
            
            self.delegate?.nicoUtilityDidReceiveHeartbeat(self, heartbeat: heartbeat!)
            
            if let interval = heartbeat?.waitTime {
                self.stopHeartbeatTimer()
                self.scheduleHeartbeatTimer(immediateFire: false, interval: NSTimeInterval(interval))
            }
        }
        
        let liveId = self.live!.liveId!
        self.cookiedAsyncRequest("GET", url: kHeartbeatUrl, parameters: ["v": liveId], completion: httpCompletion)
    }
    
    // MARK: Misc Utility
    func reset() {
        self.live = nil
        self.user = nil
        self.messageServer = nil
        
        self.messageServers.removeAll(keepCapacity: false)
        self.roomListeners.removeAll(keepCapacity: false)
        self.receivedFirstChat.removeAll(keepCapacity: false)
    }
}