//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import Starscream
import XCGLogger

// MARK: - Constants
// URLs:
private let livePageUrl = "https://live.nicovideo.jp/watch/lv"
private let userPageUrl = "https://www.nicovideo.jp/user/"
private let userNicknameApiUrl = "https://api.live2.nicovideo.jp/api/v1/user/nickname"

// Cookies:
private let userSessionCookieDomain = "nicovideo.jp"
private let userSessionCookieName = "user_session"
private let userSessionCookieExpire = TimeInterval(7200)
private let userSessionCookiePath = "/"
// Misc:
private let messageSocketPingInterval = 30
private let appHealthCheckInterval = 10
private let appHealthCheckDisconnectDetectSec = 60

// MARK: - WebSocket Messages
private let startWatchingMessage = """
{"type":"startWatching","data":{}}
"""
private let keepSeatMessage = """
{"type":"keepSeat"}
"""
private let pongMessage = """
{"type":"pong"}
"""
private let startThreadMessage = """
[{"ping":{"content":"rs:0"}},{"ping":{"content":"ps:0"}},{"thread":{"thread":"%@","version":"20061206","user_id":"%@","res_from":%d,"with_global":1,"scores":1,"nicoru":0}},{"ping":{"content":"pf:0"}},{"ping":{"content":"rf:0"}}]
"""
private let postCommentMessage = """
{"type":"postComment","data":{"text":"%@","vpos":%d,"isAnonymous":%@}}
"""

// MARK: - Class
final class NicoUtility: NicoUtilityType {
    // MARK: - Types
    enum SessionType {
        case chrome
        case safari
        case login(mail: String, password: String)
    }

    enum NicoError: Error {
        case network
        case `internal`
        case noCookieFound
        case unknown
    }
    enum ConnectContext { case normal, reconnect }
    enum DisconnectContext { case normal, reconnect }
    enum ReconnectReason { case normal, noComments }

    struct ConnectRequests {
        // swiftlint:disable nesting
        struct Request {
            let liveNumber: Int
            let sessionType: SessionType
        }
        // swiftlint:enable nesting
        var onGoing: Request?
        var lastEstablished: Request?
    }
    struct ChatNumbers {
        var latest: Int
        var maxBeforeReconnect: Int
    }
    struct LastTextSocketDates {
        var watch: Date
        var message: Date

        init() {
            watch = Date()
            message = Date()
        }
    }

    // Public Properties
    static var shared: NicoUtility = NicoUtility()
    weak var delegate: NicoUtilityDelegate?
    private(set) var live: Live?

    // Private Properties
    private var connectRequests: ConnectRequests =
        ConnectRequests(
            onGoing: nil,
            lastEstablished: nil
        )
    private var userSessionCookie: String?
    private let session: Session
    private var watchSocket: WebSocket?
    private var messageSocket: WebSocket?
    private var shouldClearUserSessionCookie = true

    // Timers for WebSockets
    private var watchSocketKeepSeatTimer: Timer?
    private var messageSocketPingTimer: Timer?

    // Usernames
    private let userNameResolvingOperationQueue = OperationQueue()
    private var cachedUserNames = [String: String]()

    // Comment Management for Reconnection
    private var chatNumbers = ChatNumbers(latest: 0, maxBeforeReconnect: 0)

    // App-side Health Check
    private var lastTextSocketDates: LastTextSocketDates?
    private var appHealthCheckTimer: Timer?

    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.headers.add(.userAgent(commonUserAgentValue))
        self.session = Session(configuration: configuration)
        clearHttpCookieStorage()
        userNameResolvingOperationQueue.maxConcurrentOperationCount = 1
    }
}

// MARK: - Public Methods (Main)
extension NicoUtility {
    func connect(liveNumber: Int, sessionType: SessionType, connectContext: NicoUtility.ConnectContext = .normal) {
        // 1. Save connection request.
        connectRequests.onGoing = ConnectRequests.Request(
            liveNumber: liveNumber,
            sessionType: sessionType
        )
        connectRequests.lastEstablished = nil

        // 2. Save chat numbers.
        switch connectContext {
        case .normal:
            chatNumbers.latest = 0
            chatNumbers.maxBeforeReconnect = 0
        case .reconnect:
            chatNumbers.maxBeforeReconnect = chatNumbers.latest
        }

        // 3. Cleanup current connection, if needed.
        if live != nil {
            disconnect()
        }

        // 4. Go direct to `connect()` IF the user session cookie is availale.
        clearUserSessionCookieIfReserved()
        delegate?.nicoUtilityWillPrepareLive(self)
        if let userSessionCookie = userSessionCookie {
            connect(
                liveNumber: liveNumber,
                userSessionCookie: userSessionCookie,
                connectContext: connectContext)
            return
        }

        // 5. Ok, there's no cookie available, go get it..
        let completion = { (userSessionCookie: String?) -> Void in
            log.debug("Cookie result: [\(sessionType)] [\(userSessionCookie ?? "-")]")
            guard let userSessionCookie = userSessionCookie else {
                let reason = "No available cookie."
                log.error(reason)
                self.delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason, error: .noCookieFound)
                return
            }
            self.connect(
                liveNumber: liveNumber,
                userSessionCookie: userSessionCookie,
                connectContext: connectContext)
        }
        switch sessionType {
        case .chrome:
            CookieUtility.requestBrowserCookie(browserType: .chrome, completion: completion)
        case .safari:
            CookieUtility.requestBrowserCookie(browserType: .safari, completion: completion)
        case .login(let mail, let password):
            CookieUtility.requestLoginCookie(mailAddress: mail, password: password, completion: completion)
        }
    }

    func disconnect(disconnectContext: NicoUtility.DisconnectContext = .normal) {
        disconnectSocketsAndResetState()
        delegate?.nicoUtilityDidDisconnect(self, disconnectContext: disconnectContext)
    }

    func reconnect(reason: ReconnectReason = .normal) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        log.debug("Reconnecting...")
        guard let lastConnection = connectRequests.lastEstablished else {
            log.warning("Failed to reconnect since there's no last established connection info.")
            return
        }
        // Nullifying `lastEstablishedConnectRequest` to prevent the `reconnect()`
        // method from being called multiple times from multiple thread.
        connectRequests.lastEstablished = nil

        disconnect(disconnectContext: {
            switch reason {
            case .normal:       return .normal
            case .noComments:   return .reconnect
            }
        }())
        delegate?.nicoUtilityWillReconnectToLive(self, reason: reason)

        // Just in case, make some delay to invoke the connect method.
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 2) {
            self.connect(
                liveNumber: lastConnection.liveNumber,
                sessionType: lastConnection.sessionType,
                connectContext: .reconnect)
        }
    }

    func comment(_ comment: String, anonymously: Bool, completion: @escaping (String?) -> Void) {
        guard let baseTime = live?.baseTime else { return }
        let elapsed = Int(Date().timeIntervalSince1970) - Int(baseTime.timeIntervalSince1970)
        let vpos = elapsed * 100
        let message = String.init(
            format: postCommentMessage,
            comment, vpos, anonymously ? "true" : "false")
        log.debug(message)
        watchSocket?.write(string: message)
    }

    func urlString(forUserId userId: String) -> String {
        return userPageUrl + userId
    }

    func reserveToClearUserSessionCookie() {
        shouldClearUserSessionCookie = true
        log.debug("reserved to clear user session cookie")
    }

    func reportAsNgUser(chat: Chat, completion: @escaping (String?) -> Void) {}
}

// MARK: - Public Methods (Username)
extension NicoUtility {
    func cachedUserName(forChat chat: Chat) -> String? {
        return cachedUserName(forUserId: chat.userId)
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
        userNameResolvingOperationQueue.addOperation { [weak self] in
            guard let me = self else { return }
            // 1. Again, chech if the user name is resolved in previous operation.
            if let cachedUsername = me.cachedUserNames[userId] {
                completion(cachedUsername)
                return
            }

            // 2.Ok, there's no cached one, request nickname api synchronously, NOT async.
            me.session.request(
                userNicknameApiUrl,
                method: .get,
                parameters: ["userId": userId]
            )
            .syncResponseData {
                switch $0.result {
                case .success(let data):
                    guard let decoded = try? JSONDecoder().decode(UserNickname.self, from: data) else {
                        log.error("error in decoding nickname response")
                        completion(nil)
                        return
                    }
                    let username = decoded.data.nickname
                    me.cachedUserNames[userId] = username
                    completion(username)
                case .failure(_):
                    log.error("error in resolving username")
                    completion(nil)
                }
            }
            log.info("Userid[\(userId)] -> [\(me.cachedUserNames[userId] ?? "-")] QueueCount: \(me.userNameResolvingOperationQueue.operationCount)")
        }
    }
}

// MARK: - Private Methods
private extension NicoUtility {
    func connect(liveNumber: Int, userSessionCookie: String, connectContext: ConnectContext) {
        self.userSessionCookie = userSessionCookie

        reqeustLiveInfo(lv: liveNumber) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let embeddedData):
                let live = embeddedData.toLive()
                let user = embeddedData.toUser()
                self?.live = live
                me.delegate?.nicoUtilityDidPrepareLive(me, user: user, live: live, connectContext: connectContext)
                me.openWatchSocket(
                    webSocketUrl: embeddedData.site.relive.webSocketUrl,
                    userId: embeddedData.user.id,
                    connectContext: connectContext
                )
            case .failure(_):
                let reason = "Failed to load live info."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason, error: nil)
            }
        }
    }

    func reqeustLiveInfo(lv: Int, completion: @escaping (Result<EmbeddedDataProperties, NicoError>) -> Void) {
        let urlRequest = urlRequestWithUserSessionCookie(
            urlString: "\(livePageUrl)\(lv)",
            userSession: userSessionCookie
        )
        let request = session.request(urlRequest)
        request.cURLDescription(calling: { log.debug($0) })
        request.responseData {
            log.debug($0.debugDescription)
            switch $0.result {
            case .success(let data):
                guard let embedded = NicoUtility.extractEmbeddedDataPropertiesFromLivePage(html: data) else {
                    completion(Result.failure(NicoError.internal))
                    return
                }
                completion(Result.success(embedded))
            case .failure(_):
                completion(Result.failure(NicoError.internal))
            }
        }
    }

    func openWatchSocket(webSocketUrl: String, userId: String, connectContext: ConnectContext) {
        openWatchSocket(webSocketUrl: webSocketUrl) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let room):
                me.openMessageSocket(userId: userId, room: room, connectContext: connectContext)
            case .failure(_):
                let reason = "Failed to load message server info."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason, error: nil)
            }
        }
    }

    func openMessageSocket(userId: String, room: WebSocketRoomData, connectContext: ConnectContext) {
        openMessageSocket(userId: userId, room: room, connectContex: connectContext) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success():
                me.startMessageSocketPingTimer(interval: messageSocketPingInterval)
                me.startAppHealthCheckTimer()
                me.connectRequests.lastEstablished = me.connectRequests.onGoing
                me.delegate?.nicoUtilityDidConnectToLive(me, roomPosition: RoomPosition.arena, connectContext: connectContext)
            case .failure(_):
                let reason = "Failed to open message server."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason, error: nil)
            }
        }
    }

    func disconnectSocketsAndResetState() {
        stopWatchSocketKeepSeatTimer()
        stopMessageSocketPingTimer()
        stopAppHealthCheckTimer()
        [watchSocket, messageSocket].forEach {
            $0?.onEvent = nil
            $0?.disconnect()
        }
        watchSocket = nil
        messageSocket = nil

        live = nil
    }
}

// MARK: Private Methods (Watch Socket)
private extension NicoUtility {
    func openWatchSocket(webSocketUrl: String, completion: @escaping (Result<WebSocketRoomData, NicoError>) -> Void) {
        guard let url = URL(string: webSocketUrl) else {
            completion(Result.failure(NicoError.internal))
            return
        }
        var request = URLRequest(url: url)
        request.headers = [commonUserAgentKey: commonUserAgentValue]
        request.timeoutInterval = 10
        let socket = WebSocket(request: request)
        socket.onEvent = { [weak self] in
            self?.handleWatchSocketEvent(
                socket: socket,
                event: $0,
                completion: completion)
        }
        socket.connect()
        watchSocket = socket
    }

    func handleWatchSocketEvent(socket: WebSocket, event: WebSocketEvent, completion: (Result<WebSocketRoomData, NicoError>) -> Void) {
        switch event {
        case .connected(_):
            log.debug("connected")
            socket.write(string: startWatchingMessage)
        case .disconnected(_, _):
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            processWebSocketData(text: text, socket: socket, completion: completion)
            lastTextSocketDates?.watch = Date()
        case .binary(_):
            log.debug("binary")
        case .pong(_):
            log.debug("pong")
        case .ping(_):
            log.debug("ping")
        case .error(_):
            log.debug("error")
            reconnect()
        case .viabilityChanged(_):
            log.debug("viabilityChanged")
        case .reconnectSuggested(_):
            log.debug("reconnectSuggested")
            reconnect()
        case .cancelled:
            log.debug("cancelled")
        }
    }

    func processWebSocketData(text: String, socket: WebSocket, completion: (Result<WebSocketRoomData, NicoError>) -> Void) {
        guard let decoded = decodeWebSocketData(text: text) else { return }
        switch decoded {
        case let seat as WebSocketSeatData:
            log.debug(seat)
            startWatchSocketKeepSeatTimer(interval: seat.data.keepIntervalSec)
        case let room as WebSocketRoomData:
            log.debug(room)
            completion(Result.success(room))
        case is WebSocketPingData:
            socket.write(string: pongMessage)
        case let stat as WebSocketStatisticsData:
            delegate?.nicoUtilityDidReceiveStatistics(self, stat: stat.toLiveStatistics())
        case is WebSocketDisconnectData:
            disconnect()
        default:
            break
        }
    }

    func decodeWebSocketData(text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        guard let wsData = try? decoder.decode(WebSocketData.self, from: data) else { return nil }
        switch wsData.type {
        case .ping:
            return try? decoder.decode(WebSocketPingData.self, from: data)
        case .seat:
            return try? decoder.decode(WebSocketSeatData.self, from: data)
        case .room:
            return try? decoder.decode(WebSocketRoomData.self, from: data)
        case .statistics:
            return try? decoder.decode(WebSocketStatisticsData.self, from: data)
        case .disconnect:
            return try? decoder.decode(WebSocketDisconnectData.self, from: data)
        }
    }
}

// MARK: - Private Methods (Message Socket)
private extension NicoUtility {
    func openMessageSocket(userId: String, room: WebSocketRoomData, connectContex: ConnectContext, completion: @escaping (Result<Void, NicoError>) -> Void) {
        guard let url = URL(string: room.data.messageServer.uri) else {
            completion(Result.failure(NicoError.internal))
            return
        }
        var request = URLRequest(url: url)
        request.headers = [
            commonUserAgentKey: commonUserAgentValue,
            "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
            "Sec-WebSocket-Protocol": "msg.nicovideo.jp#json"
        ]
        request.timeoutInterval = 10
        let socket = WebSocket(request: request)
        socket.onEvent = { [weak self] in
            self?.handleMessageSocketEvent(
                socket: socket,
                event: $0,
                userId: userId,
                threadId: room.data.threadId,
                resFrom: {
                    switch connectContex {
                    case .normal:       return -150
                    case .reconnect:    return -100
                    }
                }(),
                completion: completion)
        }
        socket.connect()
        messageSocket = socket
    }

    // swiftlint:disable function_parameter_count
    func handleMessageSocketEvent(socket: WebSocket, event: WebSocketEvent, userId: String, threadId: String, resFrom: Int, completion: (Result<Void, NicoError>) -> Void) {
        switch event {
        case .connected(_):
            log.debug("connected")
            completion(Result.success(()))
            sendStartThreadMessage(
                socket: socket,
                userId: userId,
                threadId: threadId,
                resFrom: resFrom)
        case .disconnected(_, _):
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            processChat(text: text)
            lastTextSocketDates?.message = Date()
        case .binary(_):
            log.debug("binary")
        case .pong(_):
            log.debug("pong")
        case .ping(_):
            log.debug("ping")
        case .error(_):
            log.debug("error")
            reconnect()
        case .viabilityChanged(_):
            log.debug("viabilityChanged")
        case .reconnectSuggested(_):
            log.debug("reconnectSuggested")
            reconnect()
        case .cancelled:
            log.debug("cancelled")
        }
    }
    // swiftlint:enable function_parameter_count

    func sendStartThreadMessage(socket: WebSocket, userId: String, threadId: String, resFrom: Int) {
        let message = String.init(format: startThreadMessage, threadId, userId, resFrom)
        socket.write(string: message)
    }

    func processChat(text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let _chat = try? decoder.decode(WebSocketChatData.self, from: data) else { return }
        // log.debug(_chat)
        let chat = _chat.toChat()
        guard chatNumbers.maxBeforeReconnect < chat.no else {
            log.debug("Skip duplicated chat.")
            return
        }
        chatNumbers.latest = chat.no
        delegate?.nicoUtilityDidReceiveChat(self, chat: chat)
        if _chat.isDisconnect {
            disconnect()
        }
    }
}

// MARK: - Private Methods (Keep Seat Timer for Watch Socket)
private extension NicoUtility {
    func startWatchSocketKeepSeatTimer(interval: Int) {
        stopWatchSocketKeepSeatTimer()
        watchSocketKeepSeatTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoUtility.watchScoketKeepSeatTimerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Started watch socket keep-seat timer.")
    }

    func stopWatchSocketKeepSeatTimer() {
        watchSocketKeepSeatTimer?.invalidate()
        watchSocketKeepSeatTimer = nil
        log.debug("Stopped watch socket keep-seat timer.")
    }

    @objc func watchScoketKeepSeatTimerFired() {
        log.debug("Sending keep-seat to watch socket.")
        watchSocket?.write(string: keepSeatMessage)
    }
}

// MARK: - Private Methods (Ping Timer for Message Socket)
private extension NicoUtility {
    func startMessageSocketPingTimer(interval: Int) {
        stopMessageSocketPingTimer()
        messageSocketPingTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoUtility.messageScoketPingTimerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Started message socket ping timer.")
    }

    func stopMessageSocketPingTimer() {
        messageSocketPingTimer?.invalidate()
        messageSocketPingTimer = nil
        log.debug("Stopped message socket ping timer.")
    }

    @objc func messageScoketPingTimerFired() {
        log.debug("Sending ping to message socket.")
        messageSocket?.write(ping: Data())
    }
}

// MARK: - Private Methods (App-side Health Check Timer)
private extension NicoUtility {
    func startAppHealthCheckTimer(interval: Int = appHealthCheckInterval) {
        stopAppHealthCheckTimer()
        lastTextSocketDates = .init()
        appHealthCheckTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoUtility.appHealthCheckTimerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Started app health check timer.")
    }

    func stopAppHealthCheckTimer() {
        appHealthCheckTimer?.invalidate()
        appHealthCheckTimer = nil
        log.debug("Stopped app health check timer.")
    }

    @objc func appHealthCheckTimerFired() {
        guard let lastTextSocketDates = lastTextSocketDates else {
            log.error("No information available for app health check.")
            return
        }

        // XXX: Refine the following condition, if needed.
        // No comments received for last `appHealthCheckDisconnectDetectSec`(60) seconds?
        let quietPeriod = Int(Date().timeIntervalSince(lastTextSocketDates.message))
        let shouldReconnect = appHealthCheckDisconnectDetectSec < quietPeriod
        log.debug("Quiet period: \(quietPeriod)/\(appHealthCheckDisconnectDetectSec) shouldReconnect: \(shouldReconnect)")

        if shouldReconnect {
            log.debug("Seems no comments for last \(appHealthCheckDisconnectDetectSec) sec. Reconnecting...")
            reconnect(reason: .noComments)
        }
    }
}

// MARK: - Private Utility Methods
private extension NicoUtility {
    func clearHttpCookieStorage() {
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)
    }

    func clearUserSessionCookieIfReserved() {
        guard shouldClearUserSessionCookie else { return }
        shouldClearUserSessionCookie = false
        userSessionCookie = nil
        log.debug("cleared user session cookie")
    }

    func urlRequestWithUserSessionCookie(urlString: String, userSession: String?) -> URLRequest {
        guard let url = URL(string: urlString) else {
            fatalError("This is NOT going to be happened.")
        }
        var urlRequest = URLRequest(url: url)
        if let _httpCookies = httpCookies(userSession: userSession) {
            urlRequest.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: _httpCookies)
        }
        return urlRequest
    }

    func httpCookies(userSession: String?) -> [HTTPCookie]? {
        guard let userSession = userSession,
              let sessionCookie = HTTPCookie(
                properties: [
                    HTTPCookiePropertyKey.domain: userSessionCookieDomain,
                    HTTPCookiePropertyKey.name: userSessionCookieName,
                    HTTPCookiePropertyKey.value: userSession,
                    HTTPCookiePropertyKey.expires: Date().addingTimeInterval(userSessionCookieExpire),
                    HTTPCookiePropertyKey.path: userSessionCookiePath
                ]
              ) else { return nil }
        return [sessionCookie]
    }
}

// MARK: - Private Extensions
private extension EmbeddedDataProperties {
    func toLive() -> Live {
        let live = Live()
        live.liveId = program.nicoliveProgramId
        live.title = program.title
        live.baseTime = program.vposBaseTime.toDateAsTimeIntervalSince1970()
        live.openTime = program.openTime.toDateAsTimeIntervalSince1970()
        live.startTime = program.beginTime.toDateAsTimeIntervalSince1970()
        let community = Community()
        community.community = socialGroup.id
        community.title = socialGroup.name
        community.level = socialGroup.level
        community.thumbnailUrl = URL(string: socialGroup.thumbnailImageUrl)
        live.community = community
        return live
    }

    func toUser() -> User {
        let user = User()
        user.userId = Int(self.user.id)
        user.nickname = self.user.nickname
        return user
    }
}

private extension WebSocketChatData {
    func toChat() -> Chat {
        return Chat(
            no: chat.no,
            date: chat.date.toDateAsTimeIntervalSince1970(),
            dateUsec: chat.dateUsec,
            mail: {
                guard let mail = chat.mail else { return nil }
                return [mail]
            }(),
            userId: chat.userId,
            comment: chat.content,
            premium: {
                guard let value = chat.premium,
                      let premium = Premium(rawValue: value) else { return .ippan }
                return premium
            }()
        )
    }

    var isDisconnect: Bool { chat.premium == 2 && chat.content == "/disconnect" }
}

private extension WebSocketStatisticsData {
    func toLiveStatistics() -> LiveStatistics {
        return LiveStatistics(
            viewers: data.viewers,
            comments: data.comments,
            adPoints: data.adPoints,
            giftPoints: data.giftPoints
        )
    }
}

private extension DataRequest {
    // "Synchronous" version of async `responseData()` method:
    // https://github.com/Alamofire/Alamofire/issues/1147#issuecomment-212791012
    // https://qiita.com/shtnkgm/items/d552bd3cf709266a9050#dispatchsemaphore%E3%82%92%E5%88%A9%E7%94%A8%E3%81%97%E3%81%A6%E9%9D%9E%E5%90%8C%E6%9C%9F%E5%87%A6%E7%90%86%E3%81%AE%E5%AE%8C%E4%BA%86%E3%82%92%E5%BE%85%E3%81%A4
    @discardableResult
    func syncResponseData(
        queue: DispatchQueue = .main,
        dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
        emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
        emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods,
        completionHandler: @escaping (AFDataResponse<Data>) -> Void) -> Self {
        let semaphore = DispatchSemaphore(value: 0)
        responseData(queue: queue,
                     dataPreprocessor: dataPreprocessor,
                     emptyResponseCodes: emptyResponseCodes,
                     emptyRequestMethods: emptyRequestMethods) {
            completionHandler($0)
            semaphore.signal()
        }
        semaphore.wait()
        return self
    }
}
