//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// file log
private let kFileLogName = "Hakumai_Api.log"

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
// mapping between community level and standing room is based on following articles:
private let kCommunityLevelStandRoomTable: [(levelRange: Range<Int>, standCount: Int)] = [
    (  1...49,  1),     // a
    ( 50...69,  2),     // a, b
    ( 70...104, 3),     // a, b, c
    (105...149, 4),     // a, b, c, d
    (150...189, 5),     // a, b, c, d, e
    (190...229, 6),     // a, b, c, d, e, f
    (230...255, 7),     // a, b, c, d, e, f, g
    (256...999, 9),     // a, b, c, d, e, f, g, h, i
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
    static let sharedInstance = NicoUtility()

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
    private let fileLogger = XCGLogger()

    // MARK: - Object Lifecycle
    private override init() {
        super.init()
        
        initializeFileLogger()
        initializeInstance()
    }

    func initializeFileLogger() {
        Helper.setupFileLogger(fileLogger, fileName: kFileLogName)
    }
    
    func initializeInstance() {
        resolveUserNameOperationQueue.maxConcurrentOperationCount = 1
    }

    // MARK: - Public Interface
    func reserveToClearUserSessionCookie() {
        shouldClearUserSessionCookie = true
        logger.debug("reserved to clear user session cookie")
    }
    
    func connectToLive(liveNumber: Int, mailAddress: String, password: String) {
        clearUserSessionCookieIfReserved()
        
        if userSessionCookie == nil {
            let completion = { (userSessionCookie: String?) -> Void in
                self.connectToLive(liveNumber, userSessionCookie: userSessionCookie)
            }
            CookieUtility.requestLoginCookieWithMailAddress(mailAddress, password: password, completion: completion)
        }
        else {
            connectToLive(liveNumber, userSessionCookie: userSessionCookie)
        }
    }
    
    func connectToLive(liveNumber: Int, browserType: BrowserType) {
        clearUserSessionCookieIfReserved()
        
        switch browserType {
        case .Chrome:
            connectToLive(liveNumber, userSessionCookie: CookieUtility.requestBrowserCookieWithBrowserType(.Chrome))
        default:
            break
        }
    }

    func disconnect(reserveToReconnect: Bool = false) {
        reservedToReconnect = reserveToReconnect
        
        for listener in roomListeners {
            listener.closeSocket()
        }
        
        stopHeartbeatTimer()
    }
    
    func comment(comment: String, anonymously: Bool = true, completion: (comment: String?) -> Void) {
        if live == nil || user == nil {
            logger.debug("no available stream, or user")
            return
        }
        
        let success: (String) -> () = { postKey in
            let roomListener = self.assignedRoomListener()!
            roomListener.comment(self.live!, user: self.user!, postKey: postKey, comment: comment, anonymously: anonymously)
            completion(comment: comment)
        }
        
        let failure: () -> () = {
            logger.error("could not get post key")
            completion(comment: nil)
        }
        
        requestGetPostKey(success, failure: failure)
    }
    
    func loadThumbnail(completion: (imageData: NSData?) -> Void) {
        if live?.community.thumbnailUrl == nil {
            logger.debug("no thumbnail url")
            completion(imageData: nil)
            return
        }
        
        let httpCompletion: (NSURLResponse?, NSData?, NSError?) -> () = { (response, data, connectionError) in
            if connectionError != nil {
                logger.error("error in loading thumbnail request")
                completion(imageData: nil)
                return
            }
            
            completion(imageData: data)
        }
        
        cookiedAsyncRequest("GET", url: live!.community.thumbnailUrl!, parameters: nil, completion: httpCompletion)
    }
    
    func cachedUserNameForChat(chat: Chat) -> String? {
        if chat.userId == nil {
            return nil
        }
        
        return cachedUserNameForUserId(chat.userId!)
    }
    
    func cachedUserNameForUserId(userId: String) -> String? {
        if !Chat.isRawUserId(userId) {
            return nil
        }
        
        return cachedUserNames[userId]
    }

    func resolveUsername(userId: String, completion: (userName: String?) -> Void) {
        if !Chat.isRawUserId(userId) {
            completion(userName: nil)
            return
        }
        
        if let cachedUsername = cachedUserNames[userId] {
            completion(userName: cachedUsername)
            return
        }

        if kResolveUserNameOperationQueueOverloadThreshold < resolveUserNameOperationQueue.operationCount {
            logger.debug("detected overload, so skip resolve request")
            completion(userName: nil)
            return
        }
        
        resolveUserNameOperationQueue.addOperationWithBlock {
            let resolveCompletion = { (response: NSURLResponse?, data: NSData?, connectionError: NSError?) in
                if connectionError != nil {
                    logger.error("error in resolving username")
                    completion(userName: nil)
                    return
                }
                
                let username = self.extractUsername(data!)
                self.cachedUserNames[userId] = username
                
                completion(userName: username)
            }
            
            self.cookiedAsyncRequest("GET", url: kUserUrl + String(userId), parameters: nil, completion: resolveCompletion)
        }
    }
    
    func reportAsNgUser(chat: Chat, completion: (userId: String?) -> Void) {
        let httpCompletion: (NSURLResponse?, NSData?, NSError?) -> () = { (response, data, connectionError) in
            if connectionError != nil {
                logger.error("error in requesting ng user")
                completion(userId: nil)
                return
            }
            
            logger.debug("completed to request ng user")
            completion(userId: chat.userId!)
        }
        
        let parameters: [String: Any] = [
            "vid": live!.liveId!,
            "lang": "ja-jp",
            "type": "ID",
            "locale": "GLOBAL",
            "value": chat.userId!,
            "player": "v4",
            "uid": chat.userId!,
            "tpos": String(Int(chat.date!.timeIntervalSince1970)) + "." + String(chat.dateUsec!),
            "comment": String(chat.no!),
            "thread": String(messageServers[chat.roomPosition!.rawValue].thread),
            "comment_locale": "ja-jp"
        ]
        
        cookiedAsyncRequest("POST", url: kNgScoringUrl, parameters: parameters, completion: httpCompletion)
    }
    
    func urlStringForUserId(userId: String) -> String {
        return kUserUrl + userId
    }
    
    // MARK: - RoomListenerDelegate Functions
    func roomListenerDidReceiveThread(roomListener: RoomListener, thread: Thread) {
        logger.debug("\(thread)")
        delegate?.nicoUtilityDidConnectToLive(self, roomPosition: roomListener.server!.roomPosition)
    }
    
    func roomListenerDidReceiveChat(roomListener: RoomListener, chat: Chat) {
        // logger.debug("\(chat)")
        
        if isFirstChatWithRoomListener(roomListener, chat: chat) {
            delegate?.nicoUtilityDidReceiveFirstChat(self, chat: chat)

            // open next room, if needed
            let isCurrentLastRoomChat = (chat.roomPosition?.rawValue == roomListeners.count - 1)
            if isCurrentLastRoomChat {
                logger.debug("found user comment in current last room, so try to open new message server.")
                openNewMessageServer()
            }
        }
        
        if shouldNotifyChatToDelegateWithChat(chat) {
            delegate?.nicoUtilityDidReceiveChat(self, chat: chat)
        }

        if isKickedOutWithRoomListener(roomListener, chat: chat) {
            delegate?.nicoUtilityDidGetKickedOut(self)
            reconnectToLastLive()
        }
        
        if isDisconnectedWithChat(chat) {
            disconnect()
        }
        
        chatCount += 1

        // quick test for reconnect
        #if DEBUG
            if kDebugEnableForceReconnect {
                debugForceReconnect()
            }
        #endif
    }
    
    private func debugForceReconnect() {
        if (chatCount % kDebugForceReconnectChatCount) == (kDebugForceReconnectChatCount - 1) {
            reconnectToLastLive()
        }
    }
    
    func roomListenerDidFinishListening(roomListener: RoomListener) {
        objc_sync_enter(self)
        if let index = roomListeners.indexOf(roomListener) {
            roomListeners.removeAtIndex(index)
        }
        objc_sync_exit(self)
        
        if roomListeners.count == 0 {
            delegate?.nicoUtilityDidDisconnect(self)
            reset()
            
            if reservedToReconnect {
                reservedToReconnect = false
                connectToLive(lastLiveNumber, userSessionCookie: userSessionCookie)
            }
        }
    }

    // MARK: Chat Checkers
    func isFirstChatWithRoomListener(roomListener: RoomListener, chat: Chat) -> Bool {
        if chat.isUserComment {
            if let room = roomListener.server?.roomPosition {
                if receivedFirstChat[room] == nil || receivedFirstChat[room] == false {
                    receivedFirstChat[room] = true
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
        if isAssignedMessageServerChatWithChat(chat) {
            return true
        }
        
        return false
    }
    
    func isKickedOutWithRoomListener(roomListener: RoomListener, chat: Chat) -> Bool {
        // XXX: should use isAssignedMessageServerChatWithChat()
        if roomListener.server?.roomPosition != messageServer?.roomPosition {
            return false
        }
        
        if chat.internalNo < kDefaultResFrom {
            // there is a possibility the kickout command is invoked as a result of my connection start. so ignore.
            return false
        }
        
        if chat.kickOutSeatNo == user?.seatNo {
            return true
        }
        
        return false
    }
    
    func isDisconnectedWithChat(chat: Chat) -> Bool {
        return (chat.comment == "/disconnect" && chat.isSystemComment && isAssignedMessageServerChatWithChat(chat))
    }
    
    func isAssignedMessageServerChatWithChat(chat: Chat) -> Bool {
        return chat.roomPosition == messageServer?.roomPosition
    }
    
    // MARK: - Internal Functions
    // MARK: Connect
    private func clearUserSessionCookieIfReserved() {
        if shouldClearUserSessionCookie {
            shouldClearUserSessionCookie = false
            userSessionCookie = nil
            logger.debug("cleared user session cookie")
        }
    }
    
    private func reconnectToLastLive() {
        delegate?.nicoUtilityWillReconnectToLive(self)
        disconnect(true)
    }
    
    private func connectToLive(liveNumber: Int?, userSessionCookie: String?) {
        if liveNumber == nil {
            let reason = "no valid live number"
            logger.error(reason)
            delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }
        
        if userSessionCookie == nil {
            let reason = "no available cookie"
            logger.error(reason)
            delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }
        
        self.userSessionCookie = userSessionCookie!
        self.lastLiveNumber = liveNumber!
        
        if 0 < roomListeners.count {
            logger.debug("already has established connection, so disconnect and sleep ...")
            disconnect(true)
            return
        }
        
        let success: (Live, User, MessageServer) -> () = { (live, user, server) in
            logger.debug("extracted live: \(live)")
            logger.debug("extracted server: \(server)")
            
            self.live = live
            self.user = user
            self.messageServer = server
            
            let communitySuccess: () -> () = {
                logger.debug("loaded community:\(self.live!.community)")
                
                self.delegate?.nicoUtilityDidPrepareLive(self, user: self.user!, live: self.live!)
                
                self.messageServers = self.deriveMessageServersWithOriginServer(server, community: self.live!.community)
                logger.debug("derived message servers:")
                for server in self.messageServers {
                    logger.debug("\(server)")
                }
                
                for _ in 0...self.messageServer!.roomPosition.rawValue {
                    self.openNewMessageServer()
                }
                self.scheduleHeartbeatTimer(true)
            }
            
            let communityFailure: (String) -> () = { reason in
                let reason = "failed to load community"
                logger.error(reason)
                self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
                return
            }
            
            self.loadCommunity(self.live!.community, success: communitySuccess, failure: communityFailure)
        }
        
        let failure: (String) -> () = { reason in
            logger.error(reason)
            self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
        }
        
        delegate?.nicoUtilityWillPrepareLive(self)
        requestGetPlayerStatus(liveNumber!, success: success, failure: failure)
    }
    
    private func requestGetPlayerStatus(liveNumber: Int, success: (live: Live, user: User, messageServer: MessageServer) -> Void, failure: (reason: String) -> Void) {
        let httpCompletion: (NSURLResponse?, NSData?, NSError?) -> () = { (response, data, connectionError) in
            if connectionError != nil {
                let message = "error in cookied async request"
                logger.error(message)
                failure(reason: message)
                return
            }

            // let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // fileLogger.debug("\(responseString)")

            guard let data = data else {
                let message = "error in unpacking response data"
                logger.error(message)
                failure(reason: message)
                return
            }
            
            let (error, code) = self.isErrorResponse(data)
            
            if error {
                logger.error(code)
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
                logger.error(message)
                failure(reason: message)
                return
            }
            
            success(live: live!, user: user!, messageServer: messageServer!)
        }
        
        cookiedAsyncRequest("GET", url: kGetPlayerStatusUrl, parameters: ["v": "lv" + String(liveNumber)], completion: httpCompletion)
    }
    
    private func loadCommunity(community: Community, success: () -> Void, failure: (reason: String) -> Void) {
        let httpCompletion: (NSURLResponse?, NSData?, NSError?) -> () = { (response, data, connectionError) in
            if connectionError != nil {
                let message = "error in cookied async request"
                logger.error(message)
                failure(reason: message)
                return
            }

            // let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // logger.debug("\(responseString)")

            guard let data = data else {
                let message = "error in unpacking response data"
                logger.error(message)
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
        cookiedAsyncRequest("GET", url: url, parameters: nil, completion: httpCompletion)
    }
    
    // MARK: Message Server Functions
    func deriveMessageServersWithOriginServer(originServer: MessageServer, community: Community) -> [MessageServer] {
        var arenaServer = originServer
        
        if 0 < originServer.roomPosition.rawValue {
            for _ in 1...(originServer.roomPosition.rawValue) {
                if let previous = arenaServer.previous() {
                    arenaServer = previous
                }
                else {
                    return [originServer]
                }
            }
        }
        
        var servers = [arenaServer]
        var standRoomCount = 0
        
        if community.isUser == true {
            if let level = community.level {
                standRoomCount = standRoomCountForCommunityLevel(level)
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
            if let next = servers.last!.next() {
                servers.append(next)
            }
            else {
                return [originServer]
            }
        }
        
        return servers
    }
    
    func standRoomCountForCommunityLevel(level: Int) -> Int {
        for (levelRange, standCount) in kCommunityLevelStandRoomTable {
            if levelRange.contains(level) {
                return standCount
            }
        }
        
        return 0
    }
    
    private func openNewMessageServer() {
        objc_sync_enter(self)
        
        if roomListeners.count == messageServers.count {
            logger.info("already opened max servers.")
        }
        else {
            let targetServerIndex = roomListeners.count
            let targetServer = messageServers[targetServerIndex]
            let listener = RoomListener(delegate: self, server: targetServer)
            roomListeners.append(listener)
            logger.info("created room listener instance:\(listener)")
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
                listener.openSocket(kDefaultResFrom)
            })
        }
        
        objc_sync_exit(self)
    }
    
    // MARK: Comment
    private func requestGetPostKey(success: (postKey: String) -> Void, failure: () -> Void) {
        if messageServer == nil {
            logger.error("cannot comment without messageServer")
            failure()
            return
        }
        
        let httpCompletion: (NSURLResponse?, NSData?, NSError?) -> () = { (response, data, connectionError) in
            if connectionError != nil {
                logger.error("error in cookied async request")
                failure()
                return
            }
            
            guard let data = data else {
                logger.error("error in unpacking response data")
                failure()
                return
            }

            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            logger.debug("\(responseString)")
            
            let postKey = (responseString as! String).extractRegexpPattern("postkey=(.+)")
            
            if postKey == nil {
                logger.error("error in extracting postkey")
                failure()
                return
            }
            
            success(postKey: postKey!)
        }
        
        guard let assignedRoomListener = assignedRoomListener() else {
            logger.error("could not find assigned room listener")
            failure()
            return
        }
        
        let thread = messageServer!.thread
        let blockNo = (assignedRoomListener.lastRes + 1) / 100
        
        cookiedAsyncRequest("GET", url: kGetPostKeyUrl, parameters: ["thread": thread, "block_no": blockNo], completion: httpCompletion)
    }
    
    private func assignedRoomListener() -> RoomListener? {
        var assigned: RoomListener? = nil
        
        for roomListener in roomListeners {
            if roomListener.server! == messageServer! {
                assigned = roomListener
                break
            }
        }
        
        return assigned
    }
    
    // MARK: Heartbeat
    private func scheduleHeartbeatTimer(immediateFire: Bool = false, interval: NSTimeInterval = kHeartbeatDefaultInterval) {
        stopHeartbeatTimer()
        
        dispatch_async(dispatch_get_main_queue()) {
            self.heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: #selector(NicoUtility.checkHeartbeat(_:)), userInfo: nil, repeats: true)
            if immediateFire {
                self.heartbeatTimer?.fire()
            }
        }
    }
    
    private func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    func checkHeartbeat(timer: NSTimer) {
        let httpCompletion: (NSURLResponse?, NSData?, NSError?) -> () = { (response, data, connectionError) in
            if connectionError != nil {
                logger.error("error in checking heartbeat")
                return
            }

            guard let data = data else {
                return
            }

            let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            self.fileLogger.debug("\(responseString)")
            
            let heartbeat = self.extractHeartbeat(data)
            self.fileLogger.debug("\(heartbeat)")
            
            if heartbeat == nil {
                logger.error("error in extracting heatbeat")
                return
            }
            
            self.delegate?.nicoUtilityDidReceiveHeartbeat(self, heartbeat: heartbeat!)
            
            if let interval = heartbeat?.waitTime {
                self.stopHeartbeatTimer()
                self.scheduleHeartbeatTimer(false, interval: NSTimeInterval(interval))
            }
        }
        
        // self.live may be nil if live is time-shifted. so use optional binding.
        if let liveId = live?.liveId {
            cookiedAsyncRequest("GET", url: kHeartbeatUrl, parameters: ["v": liveId], completion: httpCompletion)
        }
    }
    
    // MARK: Misc Utility
    func reset() {
        live = nil
        user = nil
        messageServer = nil
        
        messageServers.removeAll(keepCapacity: false)
        roomListeners.removeAll(keepCapacity: false)
        receivedFirstChat.removeAll(keepCapacity: false)
        
        chatCount = 0
    }
}