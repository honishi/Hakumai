//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// MARK: - enum
enum BrowserType {
    case Chrome
    case Safari
    case Firefox
}

// MARK: - protocol

// note these functions are called in background thread, not main thread.
// so use explicit main thread for updating ui in these callbacks.
protocol NicoUtilityDelegate: class {
    func nicoUtilityWillPrepareLive(nicoUtility: NicoUtility)
    func nicoUtilityDidPrepareLive(nicoUtility: NicoUtility, user: User, live: Live)
    func nicoUtilityDidFailToPrepareLive(nicoUtility: NicoUtility, reason: String)
    func nicoUtilityDidConnectToLive(nicoUtility: NicoUtility, roomPosition: RoomPosition)
    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat)
    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat)
    func nicoUtilityDidGetKickedOut(nicoUtility: NicoUtility)
    func nicoUtilityWillReconnectToLive(nicoUtility: NicoUtility)
    func nicoUtilityDidDisconnect(nicoUtility: NicoUtility)
    func nicoUtilityDidReceiveHeartbeat(nicoUtility: NicoUtility, heartbeat: Heartbeat)
}

// MARK: constant value
private let kCommunityLevelStandRoomTable: [(minLevel: Int, maxLevel: Int, standCount: Int)] = [
    (1, 65, 1),     // a
    (66, 69, 2),    // a, b
    (70, 104, 3),   // a, b, c
    (105, 149, 4),  // a, b, c, d
    (150, 189, 5),  // a, b, c, d, e
    (190, 231, 6),  // a, b, c, d, e, f
    (232, 999, 7)   // a, b, c, d, e, f, g
]

// urls for api
private let kGetPlayerStatusUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus"
private let kGetPostKeyUrl = "http://live.nicovideo.jp/api/getpostkey"
private let kHeartbeatUrl = "http://live.nicovideo.jp/api/heartbeat"
private let kNgScoringUrl:String = "http://watch.live.nicovideo.jp/api/ngscoring"

// urls for scraping
private let kCommunityUrlUser = "http://com.nicovideo.jp/community/"
private let kCommunityUrlChannel = "http://ch.nicovideo.jp/"
private let kUserUrl = "http://www.nicovideo.jp/user/"

// request header
let kCommonUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36"

// intervals & sleep
private let kHeartbeatDefaultInterval: NSTimeInterval = 30

// other threshold
private let kDefaultResFrom = 20
private let kResolveUserNameOperationQueueOverloadThreshold = 10

// debug flag
private let kDebugEnableForceReconnect = false
private let kDebugForceReconnectChatCount = 20

// MARK: - class

class NicoUtility : NSObject, RoomListenerDelegate {
    // MARK: - Properties
    weak var delegate: NicoUtilityDelegate?
    var lastLiveNumber: Int?
    
    // live core information
    var live: Live?
    private var user: User?
    private var messageServer: MessageServer?
    
    private var messageServers = [MessageServer]()
    private var roomListeners = [RoomListener]()
    private var receivedFirstChat = [RoomPosition: Bool]()

    // other variables
    private let resolveUserNameOperationQueue = NSOperationQueue()
    private var cachedUserNames = [String: String]()
    
    private var heartbeatTimer: NSTimer?
    private var reservedToReconnect = false
    private var chatCount = 0
    
    // session cookie
    private var shouldClearUserSessionCookie = true
    var userSessionCookie: String?
    
    // logger
    let log = XCGLogger.defaultInstance()
    let fileLog = XCGLogger()

    // MARK: - Object Lifecycle
    private override init() {
        super.init()
        
        self.initializeFileLog()
        self.initializeInstance()
    }
    
    class var sharedInstance : NicoUtility {
        struct Static {
            static let instance : NicoUtility = NicoUtility()
        }
        return Static.instance
    }
    
    func initializeFileLog() {
        ApiHelper.setupFileLog(fileLog, fileName: "Hakumai_Api.log")
    }
    
    func initializeInstance() {
        self.resolveUserNameOperationQueue.maxConcurrentOperationCount = 1
    }

    // MARK: - Public Interface
    func reserveToClearUserSessionCookie() {
        self.shouldClearUserSessionCookie = true
        log.debug("reserved to clear user session cookie")
    }
    
    func connectToLive(liveNumber: Int, mailAddress: String, password: String) {
        self.clearUserSessionCookieIfReserved()
        
        if self.userSessionCookie == nil {
            let completion = { (userSessionCookie: String?) -> Void in
                self.connectToLive(liveNumber, userSessionCookie: userSessionCookie)
            }
            CookieUtility.requestLoginCookieWithMailAddress(mailAddress, password: password, completion: completion)
        }
        else {
            connectToLive(liveNumber, userSessionCookie: self.userSessionCookie)
        }
    }
    
    func connectToLive(liveNumber: Int, browserType: BrowserType) {
        self.clearUserSessionCookieIfReserved()
        
        switch browserType {
        case .Chrome:
            connectToLive(liveNumber, userSessionCookie: CookieUtility.requestBrowserCookieWithBrowserType(.Chrome))
        default:
            break
        }
    }

    func disconnect(reserveToReconnect: Bool = false) {
        self.reservedToReconnect = reserveToReconnect
        
        for listener in self.roomListeners {
            listener.closeSocket()
        }
        
        self.stopHeartbeatTimer()
    }
    
    func comment(comment: String, anonymously: Bool = true, completion: (comment: String?) -> Void) {
        if self.live == nil || self.user == nil {
            self.log.debug("no available stream, or user")
            return
        }
        
        func success(postKey: String) {
            let roomListener = self.roomListeners[self.messageServer!.roomPosition.rawValue]
            roomListener.comment(self.live!, user: self.user!, postKey: postKey, comment: comment, anonymously: anonymously)
            completion(comment: comment)
        }
        
        func failure() {
            self.log.error("could not get post key")
            completion(comment: nil)
        }
        
        self.requestGetPostKey(success, failure: failure)
    }
    
    func loadThumbnail(completion: (imageData: NSData?) -> Void) {
        if self.live?.community.thumbnailUrl == nil {
            log.debug("no thumbnail url")
            completion(imageData: nil)
            return
        }
        
        func httpCompletion(response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in loading thumbnail request")
                completion(imageData: nil)
                return
            }
            
            completion(imageData: data)
        }
        
        self.cookiedAsyncRequest("GET", url: self.live!.community.thumbnailUrl!, parameters: nil, completion: httpCompletion)
    }
    
    func cachedUserNameForChat(chat: Chat) -> String? {
        if chat.userId == nil {
            return nil
        }
        
        return self.cachedUserNameForUserId(chat.userId!)
    }
    
    func cachedUserNameForUserId(userId: String) -> String? {
        if !Chat.isRawUserId(userId) {
            return nil
        }
        
        return self.cachedUserNames[userId]
    }

    func resolveUsername(userId: String, completion: (userName: String?) -> Void) {
        if !Chat.isRawUserId(userId) {
            completion(userName: nil)
            return
        }
        
        if let cachedUsername = self.cachedUserNames[userId] {
            completion(userName: cachedUsername)
            return
        }

        if kResolveUserNameOperationQueueOverloadThreshold < self.resolveUserNameOperationQueue.operationCount {
            log.debug("detected overload, so skip resolve request")
            completion(userName: nil)
            return
        }
        
        self.resolveUserNameOperationQueue.addOperationWithBlock { () -> Void in
            let resolveCompletion = { (response: NSURLResponse!, data: NSData!, connectionError: NSError!) -> Void in
                if connectionError != nil {
                    self.log.error("error in resolving username")
                    completion(userName: nil)
                    return
                }
                
                let username = self.extractUsername(data)
                self.cachedUserNames[userId] = username
                
                completion(userName: username)
            }
            
            self.cookiedAsyncRequest("GET", url: kUserUrl + String(userId), parameters: nil, completion: resolveCompletion)
        }
    }
    
    func reportAsNgUser(chat: Chat, completion: (userId: String?) -> Void) {
        func httpCompletion(response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in requesting ng user")
                completion(userId: nil)
                return
            }
            
            log.debug("completed to request ng user")
            completion(userId: chat.userId!)
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
        self.delegate?.nicoUtilityDidConnectToLive(self, roomPosition: roomListener.server!.roomPosition)
    }
    
    func roomListenerDidReceiveChat(roomListener: RoomListener, chat: Chat) {
        // log.debug("\(chat)")
        
        if self.isFirstChatWithRoomListener(roomListener, chat: chat) {
            self.delegate?.nicoUtilityDidReceiveFirstChat(self, chat: chat)

            // open next room, if needed
            let isCurrentLastRoomChat = (chat.roomPosition?.rawValue == self.roomListeners.count - 1)
            if isCurrentLastRoomChat {
                log.debug("found user comment in current last room, so try to open new message server.")
                self.openNewMessageServer()
            }
        }
        
        if self.shouldNotifyChatToDelegateWithChat(chat) {
            self.delegate?.nicoUtilityDidReceiveChat(self, chat: chat)
        }

        if self.isKickedOutWithRoomListener(roomListener, chat: chat) {
            self.delegate?.nicoUtilityDidGetKickedOut(self)
            self.reconnectToLastLive()
        }
        
        if self.isDisconnectedWithChat(chat) {
            self.disconnect()
        }
        
        self.chatCount++

        // quick test for reconnect
        #if DEBUG
            if kDebugEnableForceReconnect {
                self.debugForceReconnect()
            }
        #endif
    }
    
    private func debugForceReconnect() {
        if (self.chatCount % kDebugForceReconnectChatCount) == (kDebugForceReconnectChatCount - 1) {
            self.reconnectToLastLive()
        }
    }
    
    func roomListenerDidFinishListening(roomListener: RoomListener) {
        objc_sync_enter(self)
        if let index = find(self.roomListeners, roomListener) {
            self.roomListeners.removeAtIndex(index)
        }
        objc_sync_exit(self)
        
        if self.roomListeners.count == 0 {
            self.delegate?.nicoUtilityDidDisconnect(self)
            self.reset()
            
            if self.reservedToReconnect {
                self.reservedToReconnect = false
                self.connectToLive(self.lastLiveNumber, userSessionCookie: self.userSessionCookie)
            }
        }
    }

    // MARK: Chat Checkers
    func isFirstChatWithRoomListener(roomListener: RoomListener, chat: Chat) -> Bool {
        if chat.isUserComment {
            if let room = roomListener.server?.roomPosition {
                if self.receivedFirstChat[room] == nil || self.receivedFirstChat[room] == false {
                    self.receivedFirstChat[room] = true
                    return true
                }
            }
        }
        
        return false
    }
    
    func shouldNotifyChatToDelegateWithChat(chat: Chat) -> Bool {
        // premium == 0, 1
        if chat.isUserComment {
            return true
        }

        // comment == '/hb ifseetno xx'
        if chat.kickOutSeatNo != nil {
            return true
        }
        
        // others. is chat my assigned room's one?
        if self.isAssignedMessageServerChatWithChat(chat) {
            return true
        }
        
        return false
    }
    
    func isKickedOutWithRoomListener(roomListener: RoomListener, chat: Chat) -> Bool {
        // XXX: should use self.isAssignedMessageServerChatWithChat()
        if roomListener.server?.roomPosition != self.messageServer?.roomPosition {
            return false
        }
        
        if chat.internalNo < kDefaultResFrom {
            // there is a possibility the kickout command is invoked as a result of my connection start. so ignore.
            return false
        }
        
        if chat.kickOutSeatNo == self.user?.seatNo {
            return true
        }
        
        return false
    }
    
    func isDisconnectedWithChat(chat: Chat) -> Bool {
        return (chat.comment == "/disconnect" && chat.isSystemComment && self.isAssignedMessageServerChatWithChat(chat))
    }
    
    func isAssignedMessageServerChatWithChat(chat: Chat) -> Bool {
        return chat.roomPosition == self.messageServer?.roomPosition
    }
    
    // MARK: - Internal Functions
    // MARK: Connect
    private func clearUserSessionCookieIfReserved() {
        if self.shouldClearUserSessionCookie {
            self.shouldClearUserSessionCookie = false
            self.userSessionCookie = nil
            log.debug("cleared user session cookie")
        }
    }
    
    private func reconnectToLastLive() {
        self.delegate?.nicoUtilityWillReconnectToLive(self)
        self.disconnect(reserveToReconnect: true)
    }
    
    private func connectToLive(liveNumber: Int?, userSessionCookie: String?) {
        if liveNumber == nil {
            let reason = "no valid live number"
            log.error(reason)
            self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }
        
        if userSessionCookie == nil {
            let reason = "no available cookie"
            log.error(reason)
            self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }
        
        self.userSessionCookie = userSessionCookie!
        self.lastLiveNumber = liveNumber!
        
        if 0 < self.roomListeners.count {
            log.debug("already has established connection, so disconnect and sleep ...")
            self.disconnect(reserveToReconnect: true)
            return
        }
        
        func success(live: Live, user: User, server: MessageServer) {
            self.log.debug("extracted live: \(live)")
            self.log.debug("extracted server: \(server)")
            
            self.live = live
            self.user = user
            self.messageServer = server
            
            func communitySuccess() {
                self.log.debug("loaded community:\(self.live!.community)")
                
                self.delegate?.nicoUtilityDidPrepareLive(self, user: self.user!, live: self.live!)
                
                self.messageServers = self.deriveMessageServersWithOriginServer(server, community: self.live!.community)
                self.log.debug("derived message servers:")
                for server in self.messageServers {
                    self.log.debug("\(server)")
                }
                
                for _ in 0...self.messageServer!.roomPosition.rawValue {
                    self.openNewMessageServer()
                }
                self.scheduleHeartbeatTimer(immediateFire: true)
            }
            
            func communityFailure(reason: String) {
                let reason = "failed to load community"
                self.log.error(reason)
                self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
                return
            }
            
            self.loadCommunity(self.live!.community, success: communitySuccess, failure: communityFailure)
        }
        
        func failure(reason: String) {
            self.log.error(reason)
            self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }
        
        self.delegate?.nicoUtilityWillPrepareLive(self)
        self.requestGetPlayerStatus(liveNumber!, success: success, failure: failure)
    }
    
    private func requestGetPlayerStatus(liveNumber: Int, success: (live: Live, user: User, messageServer: MessageServer) -> Void, failure: (reason: String) -> Void) {
        func httpCompletion(response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                let message = "error in cookied async request"
                log.error(message)
                failure(reason: message)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            fileLog.debug("\(responseString)")
            
            if data == nil {
                let message = "error in unpacking response data"
                log.error(message)
                failure(reason: message)
                return
            }
            
            let (error, code) = self.isErrorResponse(data)
            
            if error {
                log.error(code)
                failure(reason: code)
                return
            }
            
            let live = self.extractLive(data)
            let user = self.extractUser(data)
            
            var messageServer: MessageServer?
            if user != nil {
                messageServer = self.extractMessageServer(data, user: user!)
            }
            
            if live == nil || user == nil || messageServer == nil {
                let message = "error in extracting getplayerstatus response"
                log.error(message)
                failure(reason: message)
                return
            }
            
            success(live: live!, user: user!, messageServer: messageServer!)
        }
        
        self.cookiedAsyncRequest("GET", url: kGetPlayerStatusUrl, parameters: ["v": "lv" + String(liveNumber)], completion: httpCompletion)
    }
    
    private func loadCommunity(community: Community, success: () -> Void, failure: (reason: String) -> Void) {
        func httpCompletion(response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                let message = "error in cookied async request"
                log.error(message)
                failure(reason: message)
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // log.debug("\(responseString)")
            
            if data == nil {
                let message = "error in unpacking response data"
                log.error(message)
                failure(reason: message)
                return
            }
            
            if community.isChannel == true {
                self.extractChannelCommunity(data, community: community)
            }
            else {
                self.extractUserCommunity(data, community: community)
            }

            success()
        }
        
        let url = (community.isChannel == true ? kCommunityUrlChannel : kCommunityUrlUser) + community.community!
        self.cookiedAsyncRequest("GET", url: url, parameters: nil, completion: httpCompletion)
    }
    
    // MARK: Message Server Functions
    func deriveMessageServersWithOriginServer(originServer: MessageServer, community: Community) -> [MessageServer] {
        var arenaServer = originServer
        
        if 0 < originServer.roomPosition.rawValue {
            for _ in 1...(originServer.roomPosition.rawValue) {
                arenaServer = arenaServer.previous()
            }
        }
        
        var servers = [arenaServer]
        var standRoomCount = 0
        
        if community.isUser == true {
            if let level = community.level {
                standRoomCount = self.standRoomCountForCommunityLevel(level)
            }
            else {
                // possible ban case. stand a, or up to assigned room
                standRoomCount = max(1, originServer.roomPosition.rawValue)
            }
        }
        else {
            // stand a, b, c, d, e
            standRoomCount = 5
        }
        
        for _ in 1...standRoomCount {
            servers.append(servers.last!.next())
        }
        
        return servers
    }
    
    func standRoomCountForCommunityLevel(level: Int) -> Int {
        var standRoomCount = 0
        
        for (minLevel, maxLevel, standCount) in kCommunityLevelStandRoomTable {
            if minLevel <= level && level <= maxLevel {
                standRoomCount = standCount
                break
            }
        }
        
        return standRoomCount
    }
    
    private func openNewMessageServer() {
        objc_sync_enter(self)
        
        if self.roomListeners.count == self.messageServers.count {
            log.info("already opened max servers.")
        }
        else {
            let targetServerIndex = self.roomListeners.count
            let targetServer = self.messageServers[targetServerIndex]
            let listener = RoomListener(delegate: self, server: targetServer)
            self.roomListeners.append(listener)
            log.info("created room listener instance:\(listener)")
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
                listener.openSocket(resFrom: kDefaultResFrom)
            })
        }
        
        objc_sync_exit(self)
    }
    
    // MARK: Comment
    private func requestGetPostKey(success: (postKey: String) -> Void, failure: () -> Void) {
        if self.messageServer == nil {
            log.error("cannot comment without messageServer")
            failure()
            return
        }
        
        func httpCompletion(response: NSURLResponse!, data: NSData!, connectionError: NSError!) {
            if connectionError != nil {
                log.error("error in cookied async request")
                failure()
                return
            }
            
            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            log.debug("\(responseString)")
            
            if data == nil {
                log.error("error in unpacking response data")
                failure()
                return
            }
            
            let postKey = (responseString as String).extractRegexpPattern("postkey=(.+)")
            
            if postKey == nil {
                log.error("error in extracting postkey")
                failure()
                return
            }
            
            success(postKey: postKey!)
        }
        
        let isMyRoomListenerOpened = (self.messageServer!.roomPosition.rawValue < roomListeners.count)
        if !isMyRoomListenerOpened {
            failure()
            return
        }
        
        let thread = self.messageServer!.thread
        let blockNo = (roomListeners[self.messageServer!.roomPosition.rawValue].lastRes + 1) / 100
        
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
        
        // self.live may be nil if live is time-shifted. so use optional binding.
        if let liveId = self.live?.liveId {
            self.cookiedAsyncRequest("GET", url: kHeartbeatUrl, parameters: ["v": liveId], completion: httpCompletion)
        }
    }
    
    // MARK: Misc Utility
    func reset() {
        self.live = nil
        self.user = nil
        self.messageServer = nil
        
        self.messageServers.removeAll(keepCapacity: false)
        self.roomListeners.removeAll(keepCapacity: false)
        self.receivedFirstChat.removeAll(keepCapacity: false)
        
        self.chatCount = 0
    }
}