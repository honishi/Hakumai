//
//  _NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// file log
private let kFileLogName = "Hakumai_Api.log"

// MARK: constant value
// mapping between community level and standing room is based on following articles:
private let kCommunityLevelStandRoomTable: [(levelRange: CountableClosedRange<Int>, standCount: Int)] = [
    (  1...49, 1),     // a
    ( 50...69, 2),     // a, b
    ( 70...104, 3),     // a, b, c
    (105...149, 4),     // a, b, c, d
    (150...189, 5),     // a, b, c, d, e
    (190...229, 6),     // a, b, c, d, e, f
    (230...255, 7),     // a, b, c, d, e, f, g
    (256...999, 9)     // a, b, c, d, e, f, g, h, i
]

// urls for api
private let kGetPlayerStatusUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus"
private let kGetPostKeyUrl = "http://live.nicovideo.jp/api/getpostkey"
private let kHeartbeatUrl = "http://live.nicovideo.jp/api/heartbeat"
private let kNgScoringUrl: String = "http://watch.live.nicovideo.jp/api/ngscoring"

// urls for scraping
private let kCommunityUrlUser = "http://com.nicovideo.jp/community/"
private let kCommunityUrlChannel = "http://ch.nicovideo.jp/"
private let kUserUrl = "http://www.nicovideo.jp/user/"

// request header
let kCommonUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36"

// intervals & sleep
private let kHeartbeatDefaultInterval: TimeInterval = 30

// other threshold
private let kDefaultResFrom = 20
private let kResolveUserNameOperationQueueOverloadThreshold = 10

// debug flag
private let kDebugEnableForceReconnect = false
private let kDebugForceReconnectChatCount = 20

final class _NicoUtility: NSObject, RoomListenerDelegate, NicoUtilityType {
    // MARK: - Properties
    static let shared = _NicoUtility()

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
    private let resolveUserNameOperationQueue = OperationQueue()
    private var cachedUserNames = [String: String]()

    private var heartbeatTimer: Timer?
    private var reservedToReconnect = false
    private var chatCount = 0
    private var resFrom = kDefaultResFrom

    // session cookie
    private var shouldClearUserSessionCookie = true
    var userSessionCookie: String?

    // logger
    private let fileLog = XCGLogger()

    // MARK: - Object Lifecycle
    private override init() {
        super.init()
        initializeFileLogger()
        initializeInstance()
    }
}

extension _NicoUtility {
    // MARK: - Public Interface
    func reserveToClearUserSessionCookie() {
        shouldClearUserSessionCookie = true
        log.debug("reserved to clear user session cookie")
    }

    func connect(liveNumber: Int, connectType: NicoConnectType) {}

    func connect(liveNumber: Int, mailAddress: String, password: String) {
        resFrom = kDefaultResFrom
        clearUserSessionCookieIfReserved()

        if userSessionCookie == nil {
            let completion = { (userSessionCookie: String?) -> Void in
                self.connect(liveNumber: liveNumber, userSessionCookie: userSessionCookie)
            }
            CookieUtility.requestLoginCookie(mailAddress: mailAddress, password: password, completion: completion)
        } else {
            connect(liveNumber: liveNumber, userSessionCookie: userSessionCookie)
        }
    }

    func connect(liveNumber: Int, browserType: BrowserType) {
        resFrom = kDefaultResFrom
        clearUserSessionCookieIfReserved()

        CookieUtility.requestBrowserCookie(browserType: browserType) { cookie in
            guard let cookie = cookie else { return }
            self.connect(liveNumber: liveNumber, userSessionCookie: cookie)
        }
    }

    func disconnect(reserveToReconnect: Bool = false) {
        reservedToReconnect = reserveToReconnect
        for listener in roomListeners {
            listener.closeSocket()
        }
        stopHeartbeatTimer()
    }

    func comment(_ comment: String, anonymously: Bool = true, completion: @escaping (_ comment: String?) -> Void) {
        guard let live = live, let user = user, let lv = live.liveId else {
            log.debug("no available stream, or user")
            return
        }
        guard let assignedRoomListener = assignedRoomListener() else {
            log.error("could not find assigned room listener")
            return
        }
        guard let json = assignedRoomListener.commentJson(live: live, user: user, comment: comment, anonymously: anonymously) else {
            log.error("could not create comment json")
            return
        }
        postCommentRequest(lv: lv, json: json) { (_, _, _) in
            // TODO: handle errors...
        }
    }

    func loadThumbnail(completion: @escaping (Data?) -> Void) {
        guard let thumbnailUrl = live?.community.thumbnailUrl else {
            log.debug("no thumbnail url")
            completion(nil)
            return
        }
        let httpCompletion: (URLResponse?, Data?, Error?) -> Void = { (_, data, connectionError) in
            if connectionError != nil {
                log.error("error in loading thumbnail request")
                completion(nil)
                return
            }
            completion(data)
        }
        cookiedAsyncRequest(httpMethod: "GET", url: thumbnailUrl.absoluteString, parameters: nil, completion: httpCompletion)
    }

    func cachedUserName(forChat chat: Chat) -> String? {
        guard let userId = chat.userId else { return nil }
        return cachedUserName(forUserId: userId)
    }

    func cachedUserName(forUserId userId: String) -> String? {
        guard Chat.isRawUserId(userId) else { return nil }
        return cachedUserNames[userId]
    }

    func resolveUsername(forUserId userId: String, completion: @escaping (String?) -> Void) {
        guard Chat.isRawUserId(userId) else {
            completion(nil)
            return
        }
        if let cachedUsername = cachedUserNames[userId] {
            completion(cachedUsername)
            return
        }
        if kResolveUserNameOperationQueueOverloadThreshold < resolveUserNameOperationQueue.operationCount {
            log.debug("detected overload, so skip resolve request")
            completion(nil)
            return
        }
        resolveUserNameOperationQueue.addOperation {
            let resolveCompletion = { (_: URLResponse?, data: Data?, connectionError: Error?) in
                guard connectionError == nil else {
                    log.error("error in resolving username")
                    completion(nil)
                    return
                }
                guard let data = data else { return }
                let username = self.extractUsername(fromHtmlData: data)
                self.cachedUserNames[userId] = username
                completion(username)
            }
            self.cookiedAsyncRequest(httpMethod: "GET", url: kUserUrl + String(userId), parameters: nil, completion: resolveCompletion)
        }
    }

    func reportAsNgUser(chat: Chat, completion: @escaping (_ userId: String?) -> Void) {
        guard let liveId = live?.liveId, let userId = chat.userId, let date = chat.date,
              let dateUsec = chat.dateUsec, let no = chat.no, let roomPosition = chat.roomPosition else { return }

        let httpCompletion: (URLResponse?, Data?, Error?) -> Void = { (_, _, connectionError) in
            guard connectionError == nil else {
                log.error("error in requesting ng user")
                completion(nil)
                return
            }
            log.debug("completed to request ng user")
            completion(userId)
        }

        let parameters: [String: Any] = [
            "vid": liveId,
            "lang": "ja-jp",
            "type": "ID",
            "locale": "GLOBAL",
            "value": userId,
            "player": "v4",
            "uid": userId,
            "tpos": String(Int(date.timeIntervalSince1970)) + "." + String(dateUsec),
            "comment": String(no),
            "thread": String(messageServers[roomPosition.rawValue].thread),
            "comment_locale": "ja-jp"
        ]
        cookiedAsyncRequest(httpMethod: "POST", url: kNgScoringUrl, parameters: parameters, completion: httpCompletion)
    }

    func urlString(forUserId userId: String) -> String {
        return kUserUrl + userId
    }

    // MARK: - RoomListenerDelegate Functions
    func roomListenerDidReceiveThread(_ roomListener: RoomListener, thread: Thread) {
        log.debug("\(thread)")
        guard let roomPosition = roomListener.server?.roomPosition else { return }
        delegate?.nicoUtilityDidConnectToLive(self, roomPosition: roomPosition)
    }

    func roomListenerDidReceiveChat(_ roomListener: RoomListener, chat: Chat) {
        // log.debug("\(chat)")
        if isFirstChat(roomListener: roomListener, chat: chat) {
            delegate?.nicoUtilityDidReceiveFirstChat(self, chat: chat)

            // open next room, if needed
            let isCurrentLastRoomChat = (chat.roomPosition?.rawValue == roomListeners.count - 1)
            if isCurrentLastRoomChat {
                log.debug("found user comment in current last room, so try to open new message server.")
                openNewMessageServer()
            }
        }

        if shouldNotifyChatToDelegate(chat: chat) {
            delegate?.nicoUtilityDidReceiveChat(self, chat: chat)
        }

        if isKickedOut(roomListener: roomListener, chat: chat) {
            delegate?.nicoUtilityDidGetKickedOut(self)
            resFrom = 0
            reconnectToLastLive()
        }

        if isDisconnected(chat: chat) {
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

    func roomListenerDidFinishListening(_ roomListener: RoomListener) {
        objc_sync_enter(self)
        if let index = roomListeners.firstIndex(of: roomListener) {
            roomListeners.remove(at: index)
        }
        objc_sync_exit(self)

        if roomListeners.count == 0 {
            delegate?.nicoUtilityDidDisconnect(self)
            reset()
            if reservedToReconnect {
                reservedToReconnect = false
                connect(liveNumber: lastLiveNumber, userSessionCookie: userSessionCookie)
            }
        }
    }

    // MARK: Message Server Functions
    func deriveMessageServers(originServer: MessageServer, community: Community) -> [MessageServer] {
        var arenaServer = originServer

        if 0 < originServer.roomPosition.rawValue {
            for _ in 1...(originServer.roomPosition.rawValue) {
                if let previous = arenaServer.previous() {
                    arenaServer = previous
                } else {
                    return [originServer]
                }
            }
        }

        var servers = [arenaServer]
        var roomCount = 0

        if community.isUser == true {
            if let level = community.level {
                roomCount = standRoomCount(forCommunityLevel: level)
            } else {
                // possible ban case. stand a, or up to assigned room
                roomCount = max(1, originServer.roomPosition.rawValue)
            }
        } else {
            // stand a, b, c, d, e
            roomCount = 5
        }

        for _ in 1...roomCount {
            if let next = servers.last?.next() {
                servers.append(next)
            } else {
                return [originServer]
            }
        }

        return servers
    }

    func standRoomCount(forCommunityLevel level: Int) -> Int {
        for (levelRange, standCount) in kCommunityLevelStandRoomTable {
            if levelRange.contains(level) {
                return standCount
            }
        }
        return 0
    }

    @objc func checkHeartbeat(_ timer: Timer) {
        let httpCompletion: (URLResponse?, Data?, Error?) -> Void = { (_, data, connectionError) in
            if connectionError != nil {
                log.error("error in checking heartbeat")
                return
            }

            guard let data = data else { return }

            let responseString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            self.fileLog.debug("\(responseString ?? "")")

            guard let heartbeat = self.extractHeartbeat(fromXmlData: data) else {
                log.error("error in extracting heatbeat")
                return
            }
            self.fileLog.debug("\(heartbeat)")

            self.delegate?.nicoUtilityDidReceiveHeartbeat(self, heartbeat: heartbeat)

            if let interval = heartbeat.waitTime {
                self.stopHeartbeatTimer()
                self.scheduleHeartbeatTimer(immediateFire: false, interval: TimeInterval(interval))
            }
        }

        // self.live may be nil if live is time-shifted. so use optional binding.
        if let liveId = live?.liveId {
            cookiedAsyncRequest(httpMethod: "GET", url: kHeartbeatUrl, parameters: ["v": liveId], completion: httpCompletion)
        }
    }
}

private extension _NicoUtility {
    func initializeFileLogger() {
        Helper.setupFileLogger(fileLog, fileName: kFileLogName)
    }

    func initializeInstance() {
        resolveUserNameOperationQueue.maxConcurrentOperationCount = 1
    }

    func debugForceReconnect() {
        if (chatCount % kDebugForceReconnectChatCount) == (kDebugForceReconnectChatCount - 1) {
            reconnectToLastLive()
        }
    }

    // MARK: Chat Checkers
    func isFirstChat(roomListener: RoomListener, chat: Chat) -> Bool {
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

    func shouldNotifyChatToDelegate(chat: Chat) -> Bool {
        // premium == 0, 1
        if chat.isUserComment {
            return true
        }
        // comment == '/hb ifseetno xx'
        if chat.kickOutSeatNo != nil {
            return true
        }
        // others. is chat my assigned room's one?
        if isAssignedMessageServerChat(chat: chat) {
            return true
        }
        return false
    }

    func isKickedOut(roomListener: RoomListener, chat: Chat) -> Bool {
        // XXX: should use isAssignedMessageServerChat()
        if roomListener.server?.roomPosition != messageServer?.roomPosition {
            return false
        }
        if let internalNo = chat.internalNo, internalNo < kDefaultResFrom {
            // there is a possibility the kickout command is invoked as a result of my connection start. so ignore.
            return false
        }
        if chat.kickOutSeatNo == user?.seatNo {
            return true
        }
        return false
    }

    func isDisconnected(chat: Chat) -> Bool {
        return (chat.comment == "/disconnect" && chat.isSystemComment && isAssignedMessageServerChat(chat: chat))
    }

    func isAssignedMessageServerChat(chat: Chat) -> Bool {
        return chat.roomPosition == messageServer?.roomPosition
    }

    // MARK: - Internal Functions
    // MARK: Connect
    func clearUserSessionCookieIfReserved() {
        guard shouldClearUserSessionCookie else { return }
        shouldClearUserSessionCookie = false
        userSessionCookie = nil
        log.debug("cleared user session cookie")
    }

    func reconnectToLastLive() {
        delegate?.nicoUtilityWillReconnectToLive(self)
        disconnect(reserveToReconnect: true)
    }

    // swiftlint:disable function_body_length
    func connect(liveNumber: Int?, userSessionCookie: String?) {
        guard let liveNumber = liveNumber else {
            let reason = "no valid live number"
            log.error(reason)
            delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }
        guard let  userSessionCookie = userSessionCookie else {
            let reason = "no available cookie"
            log.error(reason)
            delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }

        self.userSessionCookie = userSessionCookie
        self.lastLiveNumber = liveNumber

        if 0 < roomListeners.count {
            log.debug("already has established connection, so disconnect and sleep ...")
            disconnect(reserveToReconnect: true)
            return
        }

        let success: (Live, User, MessageServer) -> Void = { (live, user, server) in
            log.debug("extracted live: \(live)")
            log.debug("extracted server: \(server)")

            self.live = live
            self.user = user
            self.messageServer = server

            let communitySuccess: () -> Void = {
                guard let community = self.live?.community, let user = self.user,
                      let live = self.live, let messageServer = self.messageServer else { return }
                log.debug("loaded community:\(community)")

                self.delegate?.nicoUtilityDidPrepareLive(self, user: user, live: live)

                self.messageServers = self.deriveMessageServers(originServer: server, community: community)
                log.debug("derived message servers:")
                for server in self.messageServers {
                    log.debug("\(server)")
                }

                for _ in 0...messageServer.roomPosition.rawValue {
                    self.openNewMessageServer()
                }
                self.scheduleHeartbeatTimer(immediateFire: true)
            }

            let communityFailure: (String) -> Void = { reason in
                let reason = "failed to load community"
                log.error(reason)
                self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
                return
            }

            guard let community = self.live?.community else { return }
            self.load(community: community, success: communitySuccess, failure: communityFailure)
        }

        let failure: (String) -> Void = { reason in
            log.error(reason)
            self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
        }

        delegate?.nicoUtilityWillPrepareLive(self)
        requestGetPlayerStatus(liveNumber: liveNumber, success: success, failure: failure)
    }
    // swiftlint:enable function_body_length

    func requestGetPlayerStatus(liveNumber: Int, success: @escaping (Live, User, MessageServer) -> Void, failure: @escaping (_ reason: String) -> Void) {
        let httpCompletion: (URLResponse?, Data?, Error?) -> Void = { (_, data, connectionError) in
            if connectionError != nil {
                let message = "error in cookied async request"
                log.error(message)
                failure(message)
                return
            }
            // let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // fileLog.debug("\(responseString)")
            guard let data = data else {
                let message = "error in unpacking response data"
                log.error(message)
                failure(message)
                return
            }
            let (error, code) = self.isErrorResponse(xmlData: data)
            if error {
                log.error(code)
                failure(code)
                return
            }
            let live = self.extractLive(fromXmlData: data)
            let user = self.extractUser(fromXmlData: data)
            var messageServer: MessageServer?
            if let user = user {
                messageServer = self.extractMessageServer(fromXmlData: data, user: user)
            }
            if let live = live, let user = user, let messageServer = messageServer {
                success(live, user, messageServer)
            } else {
                let message = "error in extracting getplayerstatus response"
                log.error(message)
                failure(message)
            }
        }

        cookiedAsyncRequest(httpMethod: "GET", url: kGetPlayerStatusUrl, parameters: ["v": "lv" + String(liveNumber)], completion: httpCompletion)
    }

    func load(community: Community, success: @escaping () -> Void, failure: @escaping (_ reason: String) -> Void) {
        let httpCompletion: (URLResponse?, Data?, Error?) -> Void = { (_, data, connectionError) in
            if connectionError != nil {
                let message = "error in cookied async request"
                log.error(message)
                failure(message)
                return
            }
            // let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
            // log.debug("\(responseString)")
            guard let data = data else {
                let message = "error in unpacking response data"
                log.error(message)
                failure(message)
                return
            }
            if community.isChannel == true {
                self.extractChannelCommunity(fromHtmlData: data, community: community)
            } else {
                self.extractUserCommunity(fromHtmlData: data, community: community)
            }
            success()
        }

        guard let _community = community.community else { return }
        let url = (community.isChannel == true ? kCommunityUrlChannel : kCommunityUrlUser) + _community
        cookiedAsyncRequest(httpMethod: "GET", url: url, parameters: nil, completion: httpCompletion)
    }

    func openNewMessageServer() {
        objc_sync_enter(self)

        if roomListeners.count == messageServers.count {
            log.info("already opened max servers.")
        } else {
            let targetServerIndex = roomListeners.count
            let targetServer = messageServers[targetServerIndex]
            let listener = RoomListener(delegate: self, server: targetServer)
            roomListeners.append(listener)
            log.info("created room listener instance:\(listener)")

            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                listener.openSocket(resFrom: self.resFrom)
            }
        }

        objc_sync_exit(self)
    }

    // MARK: Comment
    func assignedRoomListener() -> RoomListener? {
        guard let messageServer = messageServer else { return nil }
        var assigned: RoomListener?
        for roomListener in roomListeners {
            guard let server = roomListener.server, server == messageServer else { continue }
            assigned = roomListener
            break
        }
        return assigned
    }

    // MARK: Heartbeat
    func scheduleHeartbeatTimer(immediateFire: Bool = false, interval: TimeInterval = kHeartbeatDefaultInterval) {
        stopHeartbeatTimer()
        DispatchQueue.main.async {
            self.heartbeatTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(NicoUtility.checkHeartbeat(_:)), userInfo: nil, repeats: true)
            if immediateFire {
                self.heartbeatTimer?.fire()
            }
        }
    }

    func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: Misc Utility
    func reset() {
        live = nil
        user = nil
        messageServer = nil
        messageServers.removeAll(keepingCapacity: false)
        roomListeners.removeAll(keepingCapacity: false)
        receivedFirstChat.removeAll(keepingCapacity: false)
        chatCount = 0
    }
}
