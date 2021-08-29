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
private let _userPageUrl = "https://www.nicovideo.jp/user/"
private let _userIconUrl = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/"

// API URL:
private let watchProgramsApiUrl = "https://api.live2.nicovideo.jp/api/v1/watch/programs"
private let userinfoApiUrl = "https://oauth.nicovideo.jp/open_id/userinfo"
private let wsEndpointApiUrl = "https://api.live2.nicovideo.jp/api/v1/wsendpoint"
private let userNicknameApiUrl = "https://api.live2.nicovideo.jp/api/v1/user/nickname"

// HTTP Header:
private let httpHeaderKeyAuthorization = "Authorization"

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
    struct ConnectRequests {
        // swiftlint:disable nesting
        struct Request {
            let liveProgramId: String
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
    private let session: Session
    private var watchSocket: WebSocket?
    private var messageSocket: WebSocket?

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
        session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(commonUserAgentValue))
            return Session(configuration: configuration)
        }()
        userNameResolvingOperationQueue.maxConcurrentOperationCount = 1
    }
}

// MARK: - Public Methods (Main)
extension NicoUtility {
    func connect(liveProgramId: String) {
        connect(liveProgramId: liveProgramId, connectContext: .normal)
    }

    func connect(liveProgramId: String, connectContext: NicoConnectContext) {
        // 1. Check if the token is existing.
        guard authManager.hasToken else {
            delegate?.nicoUtilityNeedsToken(self)
            return
        }
        delegate?.nicoUtilityDidConfirmTokenExistence(self)

        // 2. Save connection request.
        connectRequests.onGoing = ConnectRequests.Request(liveProgramId: liveProgramId)
        connectRequests.lastEstablished = nil

        // 3. Save chat numbers.
        switch connectContext {
        case .normal:
            chatNumbers.latest = 0
            chatNumbers.maxBeforeReconnect = 0
        case .reconnect:
            chatNumbers.maxBeforeReconnect = chatNumbers.latest
        }

        // 4. Cleanup current connection, if needed.
        if live != nil {
            disconnect()
        }

        // 5. Ok, start to establish connection from retrieving general live info.
        delegate?.nicoUtilityWillPrepareLive(self)
        requestLiveInfo(liveProgramId: liveProgramId, connectContext: connectContext)
    }

    func disconnect() {
        disconnect(disconnectContext: .normal)
    }

    func disconnect(disconnectContext: NicoDisconnectContext) {
        disconnectSocketsAndResetState()
        delegate?.nicoUtilityDidDisconnect(self, disconnectContext: disconnectContext)
    }

    func reconnect(reason: NicoReconnectReason = .normal) {
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

        disconnect(disconnectContext: .reconnect(reason))
        delegate?.nicoUtilityWillReconnectToLive(self, reason: reason)

        // Just in case, make some delay to invoke the connect method.
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 2) {
            self.connect(
                liveProgramId: lastConnection.liveProgramId,
                connectContext: .reconnect(reason))
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

    func logout() {
        authManager.clearToken()
    }

    func userPageUrl(for userId: String) -> URL? {
        URL(string: _userPageUrl + userId)
    }

    func userIconUrl(for userId: String) -> URL? {
        guard let number = Int(userId) else { return nil }
        let path = number / 10000
        return URL(string: "\(_userIconUrl)\(path)/\(userId).jpg")
    }

    func injectExpiredAccessToken() {
        authManager.injectExpiredAccessToken()
    }
}

// MARK: - Public Methods (Username)
extension NicoUtility {
    func cachedUserName(forChat chat: Chat) -> String? {
        cachedUserName(forUserId: chat.userId)
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
                case .failure:
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
    // #1/5. Get general live info.
    func requestLiveInfo(liveProgramId: String, connectContext: NicoConnectContext) {
        callOAuthEndpoint(
            url: watchProgramsApiUrl,
            parameters: [
                "nicoliveProgramId": liveProgramId,
                "fields": "program,socialGroup"
            ]
        ) { [weak self] (result: Result<WatchProgramsResponse, NicoError>) in
            guard let me = self else { return }
            switch result {
            case .success(let data):
                me.requestUserInfo(
                    liveProgramId: liveProgramId,
                    connectContext: connectContext,
                    live: data.toLive(with: liveProgramId))
            case .failure(let error):
                log.error(error)
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .internal)
            }
        }
    }

    // #2/5. Get user info.
    func requestUserInfo(liveProgramId: String, connectContext: NicoConnectContext, live: Live, allowRefreshToken: Bool = true) {
        callOAuthEndpoint(
            url: userinfoApiUrl
        ) { [weak self] (result: Result<UserInfoResponse, NicoError>) in
            guard let me = self else { return }
            switch result {
            case .success(let response):
                me.requestWebSocketEndpoint(
                    liveProgramId: liveProgramId,
                    connectContext: connectContext,
                    live: live,
                    user: response.toUser())
            case .failure(let error):
                log.error(error)
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .internal)
            }
        }
    }

    // #3/5. Get websocket endpoint.
    func requestWebSocketEndpoint(liveProgramId: String, connectContext: NicoConnectContext, live: Live, user: User) {
        // https://github.com/niconamaworkshop/websocket_api_document
        callOAuthEndpoint(
            url: wsEndpointApiUrl,
            parameters: [
                "nicoliveProgramId": liveProgramId,
                "userId": user.userId
            ]
        ) { [weak self] (result: Result<WsEndpointResponse, NicoError>) in
            guard let me = self else { return }
            switch result {
            case .success(let response):
                me.live = live
                me.delegate?.nicoUtilityDidPrepareLive(
                    me, user: user, live: live, connectContext: connectContext)
                // Ok, proceed to websocket calls..
                me.openWatchSocket(
                    webSocketUrl: response.data.url,
                    userId: String(user.userId),
                    connectContext: connectContext
                )
            case .failure(let error):
                log.error(error)
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .internal)
            }
        }
    }

    // #4/5. Open watch socket.
    func openWatchSocket(webSocketUrl: URL, userId: String, connectContext: NicoConnectContext) {
        openWatchSocket(webSocketUrl: webSocketUrl) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let room):
                me.openMessageSocket(userId: userId, room: room, connectContext: connectContext)
            case .failure:
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .noMessageServerInfo)
            }
        }
    }

    // #5/5. Finally, open message socket.
    func openMessageSocket(userId: String, room: WebSocketRoomData, connectContext: NicoConnectContext) {
        openMessageSocket(userId: userId, room: room, connectContext: connectContext) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success:
                me.startAllTimers()
                me.connectRequests.lastEstablished = me.connectRequests.onGoing
                me.connectRequests.onGoing = nil
                me.isConnected = true
                me.delegate?.nicoUtilityDidConnectToLive(
                    me,
                    roomPosition: RoomPosition.arena,
                    connectContext: connectContext)
            case .failure:
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, error: .openMessageServerFailed)
            }
        }
    }
}

// Methods for disconnect and timers.
private extension NicoUtility {
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
}

// Methods for OAuth endpoint calls.
private extension NicoUtility {
    func callOAuthEndpoint<T: Codable>(url: String,
                                       parameters: Alamofire.Parameters? = nil,
                                       allowRefreshToken: Bool = true,
                                       completion: @escaping (Result<T, NicoError>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(.internal))
            return
        }
        callOAuthEndpoint(
            url: url,
            parameters: parameters,
            allowRefreshToken: allowRefreshToken,
            completion: completion)
    }

    func callOAuthEndpoint<T: Codable>(url: URL,
                                       parameters: Alamofire.Parameters?,
                                       allowRefreshToken: Bool,
                                       completion: @escaping (Result<T, NicoError>) -> Void) {
        guard let accessToken = authManager.currentToken?.accessToken else {
            completion(.failure(.internal))
            return
        }
        session.request(
            url,
            method: .get,
            parameters: parameters,
            headers: authorizationHeader(with: accessToken)
        )
        .cURLDescription(calling: { log.debug($0) })
        .validate()
        .responseData { [weak self] in
            guard let me = self else { return }
            switch $0.result {
            case .success(let data):
                log.debug(String(data: data, encoding: .utf8))
                guard let response: T = me.decodeApiResponse(from: data) else {
                    completion(.failure(.internal))
                    return
                }
                completion(.success(response))
            case .failure(let error):
                log.error(error)
                // Is access token expired?
                if error.isInvalidToken, allowRefreshToken {
                    // Access token is expired, so refresh tokens..
                    me.authManager.refreshToken {
                        switch $0 {
                        case .success:
                            // Refresh token successfully completed, retry the call.
                            me.callOAuthEndpoint(
                                url: url,
                                parameters: parameters,
                                allowRefreshToken: false,   // Do NOT allow repeated refresh token.
                                completion: completion)
                        case .failure(let error):
                            log.error(error)
                            // Refresh token failed, finish to establish connection here.
                            completion(.failure(.internal))
                        }
                    }
                    return
                }
                // For normal error case, returning the error immediately.
                completion(.failure(.internal))
            }
        }
    }

    func authorizationHeader(with: String) -> HTTPHeaders {
        [httpHeaderKeyAuthorization: "Bearer \(with)"]
    }

    func decodeApiResponse<T: Codable>(from data: Data) -> T? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }
}

// MARK: Private Methods (Watch Socket)
private extension NicoUtility {
    func openWatchSocket(webSocketUrl: URL, completion: @escaping (Result<WebSocketRoomData, NicoError>) -> Void) {
        var request = URLRequest(url: webSocketUrl)
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
        case .connected:
            log.debug("connected")
            socket.write(string: startWatchingMessage)
        case .disconnected:
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            processWatchSocketTextEvent(text: text, socket: socket, completion: completion)
        case .binary:
            log.debug("binary")
        case .pong:
            log.debug("pong")
            lastPongSocketDates?.watch = Date()
        case .ping:
            log.debug("ping")
        case .error:
            log.debug("error")
            reconnect()
        case .viabilityChanged:
            log.debug("viabilityChanged")
        case .reconnectSuggested:
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
    func openMessageSocket(userId: String, room: WebSocketRoomData, connectContext: NicoConnectContext, completion: @escaping (Result<Void, NicoError>) -> Void) {
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
                    switch connectContext {
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
        case .connected:
            log.debug("connected")
            completion(Result.success(()))
            sendStartThreadMessage(
                socket: socket,
                userId: userId,
                threadId: threadId,
                resFrom: resFrom,
                threadKey: threadKey)
        case .disconnected:
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            processMessageSocketTextEvent(text: text)
            setTextSocketEventCheckTimer(delay: textEventDisconnectDetectDelay)
        case .binary:
            log.debug("binary")
        case .pong:
            log.debug("pong")
            lastPongSocketDates?.message = Date()
        case .ping:
            log.debug("ping")
        case .error:
            log.debug("error")
            reconnect()
        case .viabilityChanged:
            log.debug("viabilityChanged")
        case .reconnectSuggested:
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

// MARK: - Private Extensions
private extension WatchProgramsResponse {
    func toLive(with nicoliveProgramId: String) -> Live {
        Live(
            liveId: nicoliveProgramId,
            title: data.program.title,
            community: Community(
                communityId: data.socialGroup.socialGroupId,
                title: data.socialGroup.name,
                level: data.socialGroup.level ?? 0,
                thumbnailUrl: data.socialGroup.thumbnail
            ),
            baseTime: data.program.schedule.vposBaseTime,
            openTime: data.program.schedule.openTime,
            startTime: data.program.schedule.beginTime
        )
    }
}

private extension UserInfoResponse {
    func toUser() -> User {
        User(
            userId: sub,
            nickname: nickname
        )
    }
}

private extension WebSocketChatData {
    func toChat() -> Chat {
        Chat(
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
        LiveStatistics(
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
