//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

// swiftlint:disable file_length
import Foundation
import Alamofire
import Starscream
import XCGLogger

// MARK: - Constants
// General URL:
// TODO: remove `livePageUrl`
private let livePageUrl = "https://live.nicovideo.jp/watch/lv"
private let _livePageUrl = "https://live.nicovideo.jp/watch/"
private let _userPageUrl = "https://www.nicovideo.jp/user/"
private let _userIconUrl = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/"

// API URL:
private let userinfoApiUrl = "https://oauth.nicovideo.jp/open_id/userinfo"
private let wsEndpointApiUrl = "https://api.live2.nicovideo.jp/api/v1/wsendpoint"
private let userNicknameApiUrl = "https://api.live2.nicovideo.jp/api/v1/user/nickname"

// HTTP Header:
private let httpHeaderKeyAuthorization = "Authorization"

// Cookies:
private let userSessionCookieDomain = "nicovideo.jp"
private let userSessionCookieName = "user_session"
private let userSessionCookieExpire = TimeInterval(7200)
private let userSessionCookiePath = "/"

// Misc:
private let defaultRequestTimeout: TimeInterval = 10
private let defaultWatchSocketKeepSeatInterval = 30
private let messageSocketEmptyMessageInterval = 60
private let pingPongCheckInterval = 10
private let pongCatchDelay = 5
private let lastTextCheckInterval = 10
private let textEventDisconnectDetectDelay = 60

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
[{"ping":{"content":"rs:0"}},{"ping":{"content":"ps:0"}},{"thread":{"thread":"%@","version":"20061206","user_id":"%@","res_from":%d,"with_global":1,"scores":1,"nicoru":0,"threadkey":"%@"}},{"ping":{"content":"pf:0"}},{"ping":{"content":"rf:0"}}]
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
        case `internal`
        case noCookie
        case noLiveInfo
        case noMessageServerInfo
        case failedToOpenMessageServer
    }
    enum ConnectContext { case normal, reconnect }
    enum DisconnectContext { case normal, reconnect }
    enum ReconnectReason { case normal, noPong, noTexts }

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
    struct LastSocketDates {
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
    private let authManager: AuthManagerProtocol
    private var isConnected = false
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
    private var watchSocketKeepSeatInterval = 30
    private var watchSocketKeepSeatTimer: Timer?
    private var messageSocketEmptyMessageTimer: Timer?

    // Usernames
    private let userNameResolvingOperationQueue = OperationQueue()
    private var cachedUserNames = [String: String]()

    // Comment Management for Reconnection
    private var chatNumbers = ChatNumbers(latest: 0, maxBeforeReconnect: 0)

    // App-side Health Check (Last Pong)
    private var lastPongSocketDates: LastSocketDates?
    private var pingPongCheckTimer: Timer?
    private var pongCatchTimer: Timer?

    // App-side Health Check (Text Socket)
    private var textSocketEventCheckTimer: Timer?

    init(authManager: AuthManagerProtocol = AuthManager.shared) {
        self.authManager = authManager
        self.session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(commonUserAgentValue))
            return Session(configuration: configuration)
        }()
        clearHttpCookieStorage()
        userNameResolvingOperationQueue.maxConcurrentOperationCount = 1
    }
}

// MARK: - Public Methods (Main)
extension NicoUtility {
    func connect(liveNumber: Int, sessionType: SessionType, connectContext: NicoUtility.ConnectContext = .normal) {
        guard authManager.hasToken else {
            // TODO: Notify no token to caller.
            return
        }

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

        delegate?.nicoUtilityWillPrepareLive(self)
        // TODO: include "lv"
        refreshToken(liveProgramId: "lv\(liveNumber)", connectContext: connectContext)
    }

    // TODO: remove
    func x_connect(liveNumber: Int, sessionType: SessionType, connectContext: NicoUtility.ConnectContext = .normal) {
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
                log.error("No available cookie.")
                self.delegate?.nicoUtilityDidFailToPrepareLive(self, error: .noCookie)
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
            case .normal:           return .normal
            case .noPong, .noTexts: return .reconnect
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

    func userPageUrl(for userId: String) -> URL? {
        return URL(string: _userPageUrl + userId)
    }

    func userIconUrl(for userId: String) -> URL? {
        guard let number = Int(userId) else { return nil }
        let path = number / 10000
        return URL(string: "\(_userIconUrl)\(path)/\(userId).jpg")
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
            .validate()
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
// Main connect sequence.
private extension NicoUtility {
    // TODO: remove
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
                    userId: embeddedData.user.id ?? "0",
                    connectContext: connectContext
                )
            case .failure(_):
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .noLiveInfo)
            }
        }
    }

    // TODO: remove
    func reqeustLiveInfo(lv: Int, completion: @escaping (Result<EmbeddedDataProperties, NicoError>) -> Void) {
        let urlRequest = urlRequestWithUserSessionCookie(
            urlString: "\(livePageUrl)\(lv)",
            userSession: userSessionCookie
        )
        session.request(urlRequest)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData {
                // log.debug($0.debugDescription)
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

    // #1/5. Refresh token before proceeding main sequence.
    func refreshToken(liveProgramId: String, connectContext: ConnectContext) {
        authManager.refreshToken {
            switch $0 {
            case .success(let token):
                self.reqeustLiveInfo(
                    liveProgramId: liveProgramId,
                    accessToken: token.accessToken,
                    connectContext: connectContext
                )
            case .failure(_):
                // TODO: update error
                self.delegate?.nicoUtilityDidFailToPrepareLive(self, error: .internal)
            // TODO: clear useless stored token?
            }
        }
    }

    // #2/5. Get general live info from live page (no login required).
    func reqeustLiveInfo(liveProgramId: String, accessToken: String, connectContext: ConnectContext) {
        reqeustLiveInfo(liveProgramId: liveProgramId) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let props):
                me.requestUserInfo(
                    liveProgramId: liveProgramId,
                    accessToken: accessToken,
                    connectContext: connectContext,
                    live: props.toLive())
            case .failure(let error):
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: error)
            }
        }
    }

    // #3/5. Get user info.
    func requestUserInfo(liveProgramId: String, accessToken: String, connectContext: ConnectContext, live: Live) {
        requestUserInfo(accessToken: accessToken) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let response):
                me.requestWebSocketEndpoint(
                    liveProgramId: liveProgramId,
                    accessToken: accessToken,
                    connectContext: connectContext,
                    live: live,
                    user: response.toUser())
            case .failure(let error):
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: error)
            }
        }
    }

    // #4/5. Get websocket endpoint.
    func requestWebSocketEndpoint(liveProgramId: String, accessToken: String, connectContext: ConnectContext, live: Live, user: User) {
        requestWebSocketEndpoint(
            accessToken: accessToken,
            liveProgramId: liveProgramId,
            userId: user.userId
        ) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let response):
                me.live = live
                me.delegate?.nicoUtilityDidPrepareLive(
                    me, user: user, live: live, connectContext: connectContext)
                // #5/5. Ok, open the websockets.
                me.openWatchSocket(
                    // TODO: String -> URL
                    webSocketUrl: response.data.url.absoluteString,
                    userId: String(user.userId),
                    connectContext: connectContext
                )
            case .failure(let error):
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: error)
            }
        }
    }
}

// Methods for main connect sequence above.
private extension NicoUtility {
    func reqeustLiveInfo(liveProgramId: String, completion: @escaping (Result<EmbeddedDataProperties, NicoError>) -> Void) {
        let url = _livePageUrl + liveProgramId
        session
            .request(url)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData {
                // log.debug($0.debugDescription)
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

    func requestUserInfo(accessToken: String, completion: @escaping (Result<UserInfoResponse, NicoError>) -> Void) {
        guard let url = URL(string: userinfoApiUrl) else { return }
        session.request(
            url,
            method: .get,
            headers: authorizationHeader(with: accessToken)
        )
        .cURLDescription(calling: { log.debug($0) })
        .validate()
        .responseData { [weak self] in
            guard let me = self else { return }
            switch $0.result {
            case .success(let data):
                log.debug(String(data: data, encoding: .utf8))
                guard let response: UserInfoResponse = me.decodeApiResponse(from: data) else {
                    // TODO: update error
                    completion(.failure(.internal))
                    return
                }
                completion(.success(response))
            case .failure(let error):
                log.error(error)
                // TODO: update error
                completion(.failure(.internal))
            }
        }
    }

    // https://github.com/niconamaworkshop/websocket_api_document
    func requestWebSocketEndpoint(accessToken: String, liveProgramId: String, userId: Int, completion: @escaping (Result<WsEndpointResponse, NicoError>) -> Void) {
        guard let url = URL(string: wsEndpointApiUrl) else { return }
        session.request(
            url,
            method: .get,
            parameters: [
                "nicoliveProgramId": liveProgramId,
                "userId": userId
            ],
            headers: authorizationHeader(with: accessToken)
        )
        .cURLDescription(calling: { log.debug($0) })
        .validate()
        .responseData { [weak self] in
            guard let me = self else { return }
            switch $0.result {
            case .success(let data):
                log.debug(String(data: data, encoding: .utf8))
                guard let response: WsEndpointResponse = me.decodeApiResponse(from: data) else {
                    // TODO: update error
                    completion(.failure(.internal))
                    return
                }
                completion(.success(response))
            case .failure(let error):
                log.error(error)
                completion(.failure(.internal))
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
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .noMessageServerInfo)
            }
        }
    }

    func openMessageSocket(userId: String, room: WebSocketRoomData, connectContext: ConnectContext) {
        openMessageSocket(userId: userId, room: room, connectContex: connectContext) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success():
                me.startAllTimers()
                me.connectRequests.lastEstablished = me.connectRequests.onGoing
                me.connectRequests.onGoing = nil
                me.isConnected = true
                me.delegate?.nicoUtilityDidConnectToLive(me, roomPosition: RoomPosition.arena, connectContext: connectContext)
            case .failure(_):
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .failedToOpenMessageServer)
            }
        }
    }
}

// Methods for disconnect and timers.
private extension NicoUtility {
    func disconnectSocketsAndResetState() {
        stopAllTimers()

        [watchSocket, messageSocket].forEach {
            $0?.onEvent = nil
            $0?.disconnect()
        }
        watchSocket = nil
        messageSocket = nil

        live = nil
        isConnected = false
    }

    func startAllTimers() {
        startWatchSocketKeepSeatTimer(interval: watchSocketKeepSeatInterval)
        startMessageSocketEmptyMessageTimer(interval: messageSocketEmptyMessageInterval)
        startPingPongCheckTimer()
        log.debug("Started all timers.")
    }

    func stopAllTimers() {
        stopWatchSocketKeepSeatTimer()
        stopMessageSocketEmptyMessageTimer()
        stopPingPongCheckTimer()
        clearTextSocketEventCheckTimer()
        log.debug("Stopped all timers.")
    }
}

// Api Client Utility Methods
private extension NicoUtility {
    func authorizationHeader(with: String) -> HTTPHeaders {
        return [httpHeaderKeyAuthorization: "Bearer \(with)"]
    }

    func decodeApiResponse<T: Codable>(from data: Data) -> T? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(T.self, from: data)
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
        request.timeoutInterval = defaultRequestTimeout
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
            processWatchSocketTextEvent(text: text, socket: socket, completion: completion)
        case .binary(_):
            log.debug("binary")
        case .pong(_):
            log.debug("pong")
            lastPongSocketDates?.watch = Date()
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

    func processWatchSocketTextEvent(text: String, socket: WebSocket, completion: (Result<WebSocketRoomData, NicoError>) -> Void) {
        guard let decoded = decodeWebSocketData(text: text) else { return }
        switch decoded {
        case let seat as WebSocketSeatData:
            log.debug(seat)
            watchSocketKeepSeatInterval = seat.data.keepIntervalSec
        case let room as WebSocketRoomData:
            log.debug(room)
            completion(Result.success(room))
        case is WebSocketPingData:
            socket.write(string: pongMessage)
            log.debug("pong: \(pongMessage)")
        case let stat as WebSocketStatisticsData:
            delegate?.nicoUtilityDidReceiveStatistics(self, stat: stat.toLiveStatistics())
        case is WebSocketDisconnectData:
            disconnect()
        case is WebSocketReconnectData:
            // XXX: Add delay based on `waitTimeSec` parameter.
            reconnect()
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
        case .reconnect:
            return try? decoder.decode(WebSocketReconnectData.self, from: data)
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
                threadKey: room.data.yourPostKey,
                completion: completion)
        }
        socket.connect()
        messageSocket = socket
    }

    // swiftlint:disable function_parameter_count
    func handleMessageSocketEvent(socket: WebSocket, event: WebSocketEvent, userId: String, threadId: String, resFrom: Int, threadKey: String, completion: (Result<Void, NicoError>) -> Void) {
        switch event {
        case .connected(_):
            log.debug("connected")
            completion(Result.success(()))
            sendStartThreadMessage(
                socket: socket,
                userId: userId,
                threadId: threadId,
                resFrom: resFrom,
                threadKey: threadKey)
        case .disconnected(_, _):
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            processMessageSocketTextEvent(text: text)
            setTextSocketEventCheckTimer(delay: textEventDisconnectDetectDelay)
        case .binary(_):
            log.debug("binary")
        case .pong(_):
            log.debug("pong")
            lastPongSocketDates?.message = Date()
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

    func sendStartThreadMessage(socket: WebSocket, userId: String, threadId: String, resFrom: Int, threadKey: String) {
        let message = String.init(format: startThreadMessage, threadId, userId, resFrom, threadKey)
        socket.write(string: message)
    }

    func processMessageSocketTextEvent(text: String) {
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
            selector: #selector(NicoUtility.watchSocketKeepSeatTimerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Started watch socket keep-seat timer.")
    }

    func stopWatchSocketKeepSeatTimer() {
        watchSocketKeepSeatTimer?.invalidate()
        watchSocketKeepSeatTimer = nil
        log.debug("Stopped watch socket keep-seat timer.")
    }

    @objc func watchSocketKeepSeatTimerFired() {
        log.debug("Sending keep-seat to watch socket.")
        watchSocket?.write(string: keepSeatMessage)
    }
}

// MARK: - Private Methods (Empty Message Timer for Message Socket)
private extension NicoUtility {
    func startMessageSocketEmptyMessageTimer(interval: Int) {
        stopMessageSocketEmptyMessageTimer()
        messageSocketEmptyMessageTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoUtility.messageSocketEmptyMessageTimerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Started message socket empty-message timer.")
    }

    func stopMessageSocketEmptyMessageTimer() {
        messageSocketEmptyMessageTimer?.invalidate()
        messageSocketEmptyMessageTimer = nil
        log.debug("Stopped message socket empty-message timer.")
    }

    @objc func messageSocketEmptyMessageTimerFired() {
        log.debug("Sending empty-message to message socket.")
        messageSocket?.write(string: "")
    }
}

// MARK: - Private Methods (Ping-Pong Check Timer)
private extension NicoUtility {
    func startPingPongCheckTimer(interval: Int = pingPongCheckInterval) {
        stopPingPongCheckTimer()
        lastPongSocketDates = .init()
        pingPongCheckTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoUtility.pingPongCheckTimerFired),
            userInfo: nil,
            repeats: true)
        log.debug("Started ping-pong check timer.")
    }

    func stopPingPongCheckTimer() {
        pingPongCheckTimer?.invalidate()
        pingPongCheckTimer = nil
        pongCatchTimer?.invalidate()
        pongCatchTimer = nil
        lastPongSocketDates = nil
        log.debug("Stopped ping-pong check timer.")
    }

    @objc func pingPongCheckTimerFired() {
        let pingDate = Date()
        messageSocket?.write(ping: Data())
        pongCatchTimer?.invalidate()
        pongCatchTimer = Timer.scheduledTimer(
            timeInterval: Double(pongCatchDelay),
            target: self,
            selector: #selector(NicoUtility.pongCatchTimerFired),
            userInfo: pingDate,
            repeats: false)
    }

    @objc func pongCatchTimerFired(sender: Timer) {
        guard let pingDate = sender.userInfo as? Date,
              let pongDate = lastPongSocketDates?.message else {
            log.error("No information available for last pong check.")
            return
        }
        let isPongReceived = pongDate.timeIntervalSince(pingDate) > 0
        log.debug("ping: \(pingDate) pong: \(pongDate) isPongReceived: \(isPongReceived)")
        if !isPongReceived {
            log.debug("Seems no pong for last ping. Reconnecting...")
            reconnect(reason: .noPong)
        }
    }
}

// MARK: - Private Methods (Last Text Check Timer)
private extension NicoUtility {
    func setTextSocketEventCheckTimer(delay: Int) {
        guard isConnected else { return }
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        clearTextSocketEventCheckTimer()
        textSocketEventCheckTimer = Timer.scheduledTimer(
            timeInterval: Double(delay),
            target: self,
            selector: #selector(NicoUtility.textSocketEventCheckTimerFired),
            userInfo: nil,
            repeats: false)
        // log.debug("Set text socket event timer. (\(delay) sec)")
    }

    func clearTextSocketEventCheckTimer() {
        textSocketEventCheckTimer?.invalidate()
        textSocketEventCheckTimer = nil
        // log.debug("Clear text socket event timer.")
    }

    @objc func textSocketEventCheckTimerFired() {
        log.debug("Seems no comments for a while. Reconnecting...")
        reconnect(reason: .noTexts)
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
        return Live(
            liveId: program.nicoliveProgramId,
            title: program.title,
            community: Community(
                communityId: socialGroup.id,
                title: socialGroup.name,
                level: socialGroup.level ?? 0,
                thumbnailUrl: URL(string: socialGroup.thumbnailImageUrl)
            ),
            baseTime: program.vposBaseTime.toDateAsTimeIntervalSince1970(),
            openTime: program.openTime.toDateAsTimeIntervalSince1970(),
            startTime: program.beginTime.toDateAsTimeIntervalSince1970()
        )
    }

    // TODO: remove this obsolete method
    func toUser() -> User {
        return User(
            userId: Int(user.id ?? "-") ?? 0,
            nickname: user.nickname ?? "-"
        )
    }
}

private extension UserInfoResponse {
    func toUser() -> User {
        return User(
            userId: Int(sub) ?? 0,
            nickname: nickname
        )
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
