//
//  NicoManager.swift
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
private let _livePageUrl = "https://live.nicovideo.jp/watch/"
private let _communityPageUrl = "https://com.nicovideo.jp/community/"
private let _adPointPageUrl = "https://nicoad.nicovideo.jp/live/publish/"
private let _giftPageUrl = "https://nicoad.nicovideo.jp/nage/publish?content_id="

// API URL:
private let watchProgramsApiUrl = "https://api.live2.nicovideo.jp/api/v1/watch/programs"
private let userinfoApiUrl = "https://oauth.nicovideo.jp/open_id/userinfo"
private let wsEndpointApiUrl = "https://api.live2.nicovideo.jp/api/v1/wsendpoint"
private let userNicknameApiUrl = "https://api.live2.nicovideo.jp/api/v1/user/nickname"
private let programsRoomsApiUrl = "https://api.live2.nicovideo.jp/api/v1/unama/programs/rooms"

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
private let defaultResFrom = -999
private let initialThreadMessage = """
[{"ping":{"content":"rs:0"}},{"ping":{"content":"ps:0"}},{"thread":{"thread":"%@","version":"20061206","user_id":"%@","res_from":%d,"with_global":1,"scores":1,"nicoru":0,"threadkey":"%@"}},{"ping":{"content":"pf:0"}},{"ping":{"content":"rf:0"}}]
"""
private let historyThreadMessage = """
[{"ping":{"content":"rs:0"}},{"ping":{"content":"ps:0"}},{"thread":{"thread":"%@","version":"20061206","when":%d,"user_id":"%@","res_from":%d,"with_global":1,"scores":1,"nicoru":0}},{"ping":{"content":"pf:0"}},{"ping":{"content":"rf:0"}}]
"""
private let postCommentMessage = """
{"type":"postComment","data":{"text":"%@","vpos":%d,"isAnonymous":%@}}
"""

// MARK: - Class
final class NicoManager: NicoManagerType {
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

        static var zero: ChatNumbers { ChatNumbers(latest: 0, maxBeforeReconnect: 0) }

        func makeMaxBeforeReconnectToLatest() -> ChatNumbers {
            ChatNumbers(latest: latest, maxBeforeReconnect: latest)
        }
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
    weak var delegate: NicoManagerDelegate?
    private(set) var live: Live?

    // Private Properties
    private let authManager: AuthManagerProtocol
    private let ndgrClient: NdgrClientType

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
    private var chatNumbers: [RoomPosition: ChatNumbers] = [:]

    // App-side Health Check (Last Pong)
    private var lastPongSocketDates: LastSocketDates?
    private var pingPongCheckTimer: Timer?
    private var pongCatchTimer: Timer?

    // App-side Health Check (Text Socket)
    private var textSocketEventCheckTimer: Timer?

    // History Comments
    private var earliestHistoryChatDate: Date = .distantFuture
    private var historyThreadRequestCount = 0
    private var chatCountIn1HistoryThreadRequest = 0
    private var historyChats: [Chat] = []
    private var receivedAllHistoryChats = false

    init(authManager: AuthManagerProtocol = AuthManager.shared, ndgrClient: NdgrClientType = NdgrClient()) {
        self.authManager = authManager
        self.ndgrClient = ndgrClient
        session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(commonUserAgentValue))
            return Session(configuration: configuration)
        }()
        userNameResolvingOperationQueue.maxConcurrentOperationCount = 1
    }
}

// MARK: - Public Methods (Main)
extension NicoManager {
    func connect(liveProgramId: String) {
        connect(liveProgramId: liveProgramId, connectContext: .normal)
    }

    func connect(liveProgramId: String, connectContext: NicoConnectContext) {
        // 0. Configure delegate.
        ndgrClient.delegate = self

        // 1. Check if the token is existing.
        guard authManager.hasToken else {
            delegate?.nicoManagerNeedsToken(self)
            return
        }
        delegate?.nicoManagerDidConfirmTokenExistence(self)

        // 2. Save connection request.
        connectRequests.onGoing = ConnectRequests.Request(liveProgramId: liveProgramId)
        connectRequests.lastEstablished = nil

        // 3. Save chat numbers.
        for room in RoomPosition.allCases {
            switch connectContext {
            case .normal:
                chatNumbers[room] = .zero
            case .reconnect:
                chatNumbers[room] = chatNumbers[room]?.makeMaxBeforeReconnectToLatest()
            }
        }

        // 4. Cleanup current connection, if needed.
        if live != nil {
            disconnect()
        }

        // 5. Ok, start to establish connection from retrieving general live info.
        delegate?.nicoManagerWillPrepareLive(self)
        requestLiveInfo(liveProgramId: liveProgramId, connectContext: connectContext)
    }

    func disconnect() {
        disconnect(disconnectContext: .normal)
    }

    func disconnect(disconnectContext: NicoDisconnectContext) {
        ndgrClient.disconnect()
        disconnectSocketsAndResetState()
        delegate?.nicoManagerDidDisconnect(self, disconnectContext: disconnectContext)
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
        delegate?.nicoManagerWillReconnectToLive(self, reason: reason)

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

    func livePageUrl(for liveProgramId: String) -> URL? {
        URL(string: _livePageUrl + liveProgramId)
    }

    func communityPageUrl(for communityId: String) -> URL? {
        URL(string: _communityPageUrl + communityId)
    }

    func adPageUrl(for liveProgramId: String) -> URL? {
        URL(string: _adPointPageUrl + liveProgramId)
    }

    func giftPageUrl(for liveProgramId: String) -> URL? {
        URL(string: _giftPageUrl + liveProgramId)
    }

    func injectExpiredAccessToken() {
        authManager.injectExpiredAccessToken()
    }
}

// MARK: - Public Methods (Username)
extension NicoManager {
    func cachedUserName(for userId: String) -> String? {
        guard userId.isRawUserId else { return nil }
        return cachedUserNames[userId]
    }

    func resolveUsername(for userId: String, completion: @escaping (String?) -> Void) {
        guard userId.isRawUserId else {
            completion(nil)
            return
        }
        if let cachedUsername = cachedUserNames[userId] {
            completion(cachedUsername)
            return
        }
        userNameResolvingOperationQueue.addOperation { [weak self] in
            guard let me = self else { return }
            // 1. Again, check if the user name is resolved in previous operation.
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

// MARK: - NdgrClientDelegate Methods
extension NicoManager: NdgrClientDelegate {
    func ndgrClientDidConnect(_ ndgrClient: any NdgrClientType) {
        log.info("ndgr client connected.")
        delegate?.nicoManager(self, hasDebugMessgae: "Completed to open message socket.")
        connectRequests.lastEstablished = connectRequests.onGoing
        connectRequests.onGoing = nil
        isConnected = true
        startBasicTimers()
        delegate?.nicoManagerDidConnectToLive(
            self,
            roomPosition: RoomPosition.arena,
            // TODO: context を正しく渡す必要があるか検討
            // connectContext: connectContext
            connectContext: .normal
        )
    }

    func ndgrClientReceivingChatHistory(_ ndgrClient: any NdgrClientType, requestCount: Int, totalChatCount: Int) {
        delegate?.nicoManagerReceivingChatHistory(self, requestCount: requestCount, totalChatCount: totalChatCount)
    }

    func ndgrClientDidReceiveChatHistory(_ ndgrClient: any NdgrClientType, chats: [Chat]) {
        delegate?.nicoManagerDidReceiveChatHistory(self, chats: chats)
    }

    func ndgrClientDidReceiveChat(_ ndgrClient: any NdgrClientType, chat: Chat) {
        delegate?.nicoManagerDidReceiveChat(self, chat: chat)
    }

    func ndgrClientDidDisconnect(_ ndgrClient: any NdgrClientType) {
        log.info("ndgr client disconnected.")
        delegate?.nicoManagerDidDisconnect(self, disconnectContext: .normal)
    }
}

// MARK: - Private Methods
// Main connect sequence.
private extension NicoManager {
    // #1/5. Get general live info.
    func requestLiveInfo(liveProgramId: String, connectContext: NicoConnectContext) {
        delegate?.nicoManager(self, hasDebugMessgae: "Requesting live info...")
        callOAuthEndpoint(
            url: watchProgramsApiUrl,
            parameters: [
                "nicoliveProgramId": liveProgramId,
                "fields": "program,programProvider"
            ]
        ) { [weak self] (result: Result<WatchProgramsResponse, NicoError>) in
            guard let me = self else { return }
            switch result {
            case .success(let data):
                if data.isNotStarted {
                    me.delegate?.nicoManagerDidFailToPrepareLive(me, error: .notStarted)
                    return
                }
                me.delegate?.nicoManager(me, hasDebugMessgae: "Completed to request live info.")
                me.requestUserInfo(
                    liveProgramId: liveProgramId,
                    connectContext: connectContext,
                    live: data.toLive(with: liveProgramId))
            case .failure(let error):
                log.error(error)
                me.delegate?.nicoManager(
                    me,
                    hasDebugMessgae: "Failed to request live info. (\(error))")
                me.delegate?.nicoManagerDidFailToPrepareLive(me, error: .internal)
            }
        }
    }

    // #2/5. Get user info.
    func requestUserInfo(liveProgramId: String, connectContext: NicoConnectContext, live: Live, allowRefreshToken: Bool = true) {
        delegate?.nicoManager(self, hasDebugMessgae: "Requesting user info...")
        callOAuthEndpoint(
            url: userinfoApiUrl
        ) { [weak self] (result: Result<UserInfoResponse, NicoError>) in
            guard let me = self else { return }
            switch result {
            case .success(let response):
                me.delegate?.nicoManager(me, hasDebugMessgae: "Completed to request user info.")
                me.requestWebSocketEndpoint(
                    liveProgramId: liveProgramId,
                    connectContext: connectContext,
                    live: live,
                    user: response.toUser())
            case .failure(let error):
                log.error(error)
                me.delegate?.nicoManager(
                    me,
                    hasDebugMessgae: "Failed to request user info. (\(error))")
                me.delegate?.nicoManagerDidFailToPrepareLive(me, error: .internal)
            }
        }
    }

    // #3/5. Get websocket endpoint.
    func requestWebSocketEndpoint(liveProgramId: String, connectContext: NicoConnectContext, live: Live, user: User) {
        delegate?.nicoManager(self, hasDebugMessgae: "Requesting websocket endpoint...")
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
                me.delegate?.nicoManager(me, hasDebugMessgae: "Completed to request websocket endpoint.")
                me.live = live
                me.delegate?.nicoManagerDidPrepareLive(
                    me, user: user, live: live, connectContext: connectContext)
                // Ok, proceed to websocket calls..
                me.openWatchSocket(
                    webSocketUrl: response.data.url,
                    userId: String(user.userId),
                    connectContext: connectContext
                )
            case .failure(let error):
                log.error(error)
                me.delegate?.nicoManager(
                    me,
                    hasDebugMessgae: "Failed to request websocket endpoint. (\(error))")
                me.delegate?.nicoManagerDidFailToPrepareLive(me, error: .internal)
            }
        }
    }

    // #4/5. Open watch socket.
    func openWatchSocket(webSocketUrl: URL, userId: String, connectContext: NicoConnectContext) {
        delegate?.nicoManager(self, hasDebugMessgae: "Opening watch socket...")
        openWatchSocket(webSocketUrl: webSocketUrl) { [weak self] in
            guard let me = self, let live = me.live else { return }
            switch $0 {
            case .success(let messageServer):
                me.delegate?.nicoManager(me, hasDebugMessgae: "Completed to open watch socket.")
                me.connectToNdgrServer(
                    userId: userId,
                    messageServer: messageServer,
                    connectContext: connectContext,
                    beginTime: live.beginTime,
                    isTimeShift: live.isTimeShift
                )
            case .failure(let error):
                me.delegate?.nicoManager(
                    me,
                    hasDebugMessgae: "Failed to open watch socket. (\(error))")
                me.delegate?.nicoManagerDidFailToPrepareLive(me, error: .noMessageServerInfo)
            }
        }
    }

    // #5/5. Finally, connect to ndgr server.
    func connectToNdgrServer(
        userId: String,
        messageServer: WebSocketMessageServerData,
        connectContext: NicoConnectContext,
        beginTime: Date,
        isTimeShift: Bool
    ) {
        delegate?.nicoManager(self, hasDebugMessgae: "Connecting to ngdr server...")
        guard let url = URL(string: messageServer.data.viewUri) else {
            log.error("viewuri parse error.")
            return
        }
        ndgrClient.connect(viewUri: url, beginTime: beginTime)
        /*
         openMessageSocket(userId: userId, room: room, connectContext: connectContext, isTimeShift: isTimeShift) { [weak self] in
         guard let me = self else { return }
         switch $0 {
         case .success:
         me.delegate?.nicoManager(me, hasDebugMessgae: "Completed to open message socket.")
         me.connectRequests.lastEstablished = me.connectRequests.onGoing
         me.connectRequests.onGoing = nil
         me.isConnected = true
         me.openedRoomCount = 1
         me.startBasicTimers()
         me.delegate?.nicoManagerDidConnectToLive(
         me,
         roomPosition: RoomPosition.arena,
         connectContext: connectContext)
         case .failure(let error):
         me.delegate?.nicoManager(
         me,
         hasDebugMessgae: "Failed to open message socket. (\(error))")
         me.delegate?.nicoManagerDidFailToPrepareLive(me, error: .openMessageServerFailed)
         }
         }
         */
    }
}

// Methods for disconnect and timers.
private extension NicoManager {
    func startBasicTimers() {
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
            $0?.disconnect()
        }
        // To wait the completion of the above socket disconnect operation, skip to
        // immediate-nullify `watchSocket` and `messageSocket` here.
        // It's okay not to nullify them since they, in any case, are nullified
        // in the next open socket methods.
        // If we nullify them immediately here, these sockets are remained incompletely
        // in the status like `CloseWait`. And they are piled up and eventually cause
        // the network error for new connect requests with the message like
        // “No space left on device”.
        // You can confirm this "memory leak" in Network Activity Report in Xcode.

        live = nil
        isConnected = false
    }
}

// Methods for OAuth endpoint calls.
private extension NicoManager {
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

    // swiftlint:disable function_body_length
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
                log.debug(String(decoding: data, as: UTF8.self))
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
                    me.delegate?.nicoManager(
                        me,
                        hasDebugMessgae: "Access token is expired, refreshing token...")
                    me.authManager.refreshToken {
                        switch $0 {
                        case .success:
                            // Refresh token successfully completed, retry the call.
                            me.delegate?.nicoManager(
                                me,
                                hasDebugMessgae: "Completed to refresh token.")
                            me.callOAuthEndpoint(
                                url: url,
                                parameters: parameters,
                                allowRefreshToken: false,   // Do NOT allow repeated refresh token.
                                completion: completion)
                        case .failure(let error):
                            log.error(error)
                            // Refresh token failed, finish to establish connection here.
                            me.delegate?.nicoManager(
                                me,
                                hasDebugMessgae: "Failed to refresh token. (\(error))")
                            completion(.failure(.internal))
                        }
                    }
                    return
                }
                // For normal error case, returning the error immediately.
                me.delegate?.nicoManager(
                    me,
                    hasDebugMessgae: "Failed to call OAuth endpoint. (\(error))")
                completion(.failure(.internal))
            }
        }
    }
    // swiftlint:enable function_body_length

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
private extension NicoManager {
    func openWatchSocket(webSocketUrl: URL, completion: @escaping (Result<WebSocketMessageServerData, NicoError>) -> Void) {
        var request = URLRequest(url: webSocketUrl)
        request.applyDefaultWatchSocketSetting()
        let socket = WebSocket(request: request)
        socket.onEvent = { [weak self, weak socket] in
            guard let me = self, let socket = socket else { return }
            me.handleWatchSocketEvent(
                socket: socket,
                event: $0,
                completion: completion)
        }
        socket.connect()
        watchSocket = socket
    }

    func handleWatchSocketEvent(socket: WebSocket, event: WebSocketEvent, completion: (Result<WebSocketMessageServerData, NicoError>) -> Void) {
        log.debug(event)
        switch event {
        case .connected:
            socket.write(string: startWatchingMessage)
        case .text(let text):
            log.debug(text)
            processWatchSocketTextEvent(text: text, socket: socket, completion: completion)
        case .pong:
            lastPongSocketDates?.watch = Date()
        case .error(let error):
            delegate?.nicoManager(self, hasDebugMessgae: "Watch socket error. (\(String(describing: error)))")
            reconnect()
        case .reconnectSuggested:
            reconnect()
        case .binary, .cancelled, .disconnected, .ping, .viabilityChanged, .peerClosed:
            break
        }
    }

    func processWatchSocketTextEvent(text: String, socket: WebSocket, completion: (Result<WebSocketMessageServerData, NicoError>) -> Void) {
        guard let decoded = decodeWebSocketData(text: text) else { return }
        switch decoded {
        case let seat as WebSocketSeatData:
            log.debug(seat)
            watchSocketKeepSeatInterval = seat.data.keepIntervalSec
        case let messageServer as WebSocketMessageServerData:
            log.debug(messageServer)
            completion(Result.success(messageServer))
        case is WebSocketPingData:
            socket.write(string: pongMessage)
            log.debug("pong: \(pongMessage)")
        case let stat as WebSocketStatisticsData:
            delegate?.nicoManagerDidReceiveStatistics(self, stat: stat.toLiveStatistics())
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
        case .messageServer:
            return try? decoder.decode(WebSocketMessageServerData.self, from: data)
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
private extension NicoManager {
    /*
     func openMessageSocket(userId: String, room: WebSocketRoomData, connectContext: NicoConnectContext, isTimeShift: Bool, completion: @escaping (Result<Void, NicoError>) -> Void) {
     guard let url = URL(string: room.data.messageServer.uri) else {
     completion(Result.failure(NicoError.internal))
     return
     }
     if !connectContext.isReconnect {
     resetChatHistoryVariables()
     }
     var request = URLRequest(url: url)
     request.applyDefaultMessageSocketSetting()
     let socket = WebSocket(request: request)
     socket.onEvent = { [weak self, weak socket] in
     guard let me = self, let socket = socket else { return }
     me.handleMessageSocketEvent(
     socket: socket,
     event: $0,
     userId: userId,
     threadId: room.data.threadId,
     resFrom: defaultResFrom,
     threadKey: room.data.yourPostKey,
     isReconnect: connectContext.isReconnect,
     isTimeShift: isTimeShift,
     completion: completion
     )
     }
     socket.connect()
     messageSocket = socket
     }
     */

    // swiftlint:disable function_parameter_count
    func handleMessageSocketEvent(
        socket: WebSocket,
        event: WebSocketEvent,
        userId: String,
        threadId: String,
        resFrom: Int,
        threadKey: String,
        isReconnect: Bool,
        isTimeShift: Bool,
        completion: (Result<Void, NicoError>) -> Void
    ) {
        // log.debug(event)
        switch event {
        case .connected:
            completion(Result.success(()))
            sendInitialThreadMessage(
                socket: socket,
                userId: userId,
                threadId: threadId,
                resFrom: resFrom,
                threadKey: threadKey
            )
        case .text(let text):
            // "receiving history in progress" && "not reconnect mode"
            if !receivedAllHistoryChats && !isReconnect {
                handleHistoryTextEvent(
                    text: text,
                    socket: socket,
                    userId: userId,
                    threadId: threadId,
                    isTimeShift: isTimeShift
                )
            } else {
                handleNormalTextEvent(text: text)
            }
        case .pong:
            lastPongSocketDates?.message = Date()
        case .error(let error):
            delegate?.nicoManager(self, hasDebugMessgae: "Message socket error. (\(String(describing: error)))")
            reconnect()
        case .reconnectSuggested:
            reconnect()
        case .binary, .cancelled, .disconnected, .ping, .viabilityChanged, .peerClosed:
            break
        }
    }
    // swiftlint:enable function_parameter_count

    func sendInitialThreadMessage(socket: WebSocket, userId: String, threadId: String, resFrom: Int, threadKey: String) {
        let message = String.init(
            format: initialThreadMessage,
            threadId,
            userId,
            resFrom,
            threadKey
        )
        // log.debug(message)
        socket.write(string: message)
    }

    func sendHistoryThreadMessage(socket: WebSocket, userId: String, threadId: String, resFrom: Int, when: Date) {
        let message = String.init(
            format: historyThreadMessage,
            threadId,
            Int(when.timeIntervalSince1970),
            userId,
            resFrom)
        // log.debug(message)
        socket.write(string: message)
    }

    func handleHistoryTextEvent(text: String, socket: WebSocket, userId: String, threadId: String, isTimeShift: Bool) {
        let result = decodeHistoryMessageSocketTextEvent(text: text)
        switch result {
        case .pingContentStart:
            chatCountIn1HistoryThreadRequest = 0
        case .chat(let chat):
            earliestHistoryChatDate = min(earliestHistoryChatDate, chat.date)
            historyChats.append(chat)
            updateChatNumbers(chat: chat)
            chatCountIn1HistoryThreadRequest += 1
        case .pingContentFinish:
            delegate?.nicoManager(
                self,
                hasDebugMessgae: "Received history chats: \(historyChats.count)"
            )
            let receivedAnyChats = chatCountIn1HistoryThreadRequest > 0
            if receivedAnyChats {
                delegate?.nicoManagerReceivingChatHistory(
                    self,
                    requestCount: historyThreadRequestCount,
                    totalChatCount: historyChats.count)
            }
            let receivedAllChats = chatCountIn1HistoryThreadRequest == 0
            // log.debug(receivedAllChats)
            let tooManyRequest = 100 < historyThreadRequestCount
            if receivedAllChats || tooManyRequest {
                historyChats.sort(by: { a, b in a.date < b.date })
                delegate?.nicoManagerDidReceiveChatHistory(self, chats: historyChats)
                if isTimeShift {
                    disconnect()
                } else {
                    setTextSocketEventCheckTimer(delay: textEventDisconnectDetectDelay)
                }
                receivedAllHistoryChats = true
                break
            }
            sendHistoryThreadMessage(
                socket: socket,
                userId: userId,
                threadId: threadId,
                resFrom: defaultResFrom,
                when: earliestHistoryChatDate
            )
            historyThreadRequestCount += 1
        case .unknown:
            break
        }
    }

    func handleNormalTextEvent(text: String) {
        guard isConnected else {
            log.debug("Skip processing message text. (Disconnected already.)")
            return
        }
        guard let chat = decodeMessageSocketTextEvent(text: text) else { return }
        if let max = chatNumbers[chat.roomPosition]?.maxBeforeReconnect, chat.no <= max {
            log.debug("Skip duplicated chat.")
        } else {
            delegate?.nicoManagerDidReceiveChat(self, chat: chat)
        }
        updateChatNumbers(chat: chat)
        if chat.isDisconnect {
            disconnect()
        }
        setTextSocketEventCheckTimer(delay: textEventDisconnectDetectDelay)
    }

    enum MessageSocketProcessResult {
        case chat(Chat)
        case pingContentStart
        case pingContentFinish
        case unknown
    }

    func decodeHistoryMessageSocketTextEvent(text: String) -> MessageSocketProcessResult {
        guard let data = text.data(using: .utf8) else { return .unknown }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let pc = try? decoder.decode(WebSocketPingContentData.self, from: data) {
            if pc.ping.content == "rs:0" {
                return .pingContentStart
            } else if pc.ping.content == "rf:0" {
                return .pingContentFinish
            }
            return .unknown
        }
        guard let chat = try? decoder.decode(WebSocketChatData.self, from: data) else { return .unknown }
        return .chat(chat.toChat(roomPosition: .arena))
    }

    func decodeMessageSocketTextEvent(text: String) -> Chat? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let _chat = try? decoder.decode(WebSocketChatData.self, from: data) else { return nil }
        // log.debug(_chat)
        let room = roomPosition(of: _chat)
        let chat = _chat.toChat(roomPosition: room)
        guard room == .arena || (room != .arena && chat.premium.isUser) else {
            log.debug("Ignore chat: \(chat)")
            return nil
        }
        return chat
    }

    func roomPosition(of chat: WebSocketChatData) -> RoomPosition {
        return .arena
        /*
         let index = programRooms.map({ $0.threadId }).firstIndex(of: chat.chat.thread)
         guard let index = index else { return .arena }
         return RoomPosition(rawValue: index) ?? .arena
         */
    }

    func updateChatNumbers(chat: Chat) {
        chatNumbers[chat.roomPosition]?.latest = chat.no
    }

    func resetChatHistoryVariables() {
        receivedAllHistoryChats = false
        earliestHistoryChatDate = .distantFuture
        historyThreadRequestCount = 0
        chatCountIn1HistoryThreadRequest = 0
        historyChats.removeAll()
    }
}

private extension URLRequest {
    mutating func applyDefaultWatchSocketSetting() {
        headers = [
            commonUserAgentKey: commonUserAgentValue
        ]
        timeoutInterval = defaultRequestTimeout
    }

    mutating func applyDefaultMessageSocketSetting() {
        headers = [
            commonUserAgentKey: commonUserAgentValue,
            "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
            "Sec-WebSocket-Protocol": "msg.nicovideo.jp#json"
        ]
        timeoutInterval = defaultRequestTimeout
    }
}

// MARK: - Private Methods (Keep Seat Timer for Watch Socket)
private extension NicoManager {
    func startWatchSocketKeepSeatTimer(interval: Int) {
        stopWatchSocketKeepSeatTimer()
        watchSocketKeepSeatTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoManager.watchSocketKeepSeatTimerFired),
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
private extension NicoManager {
    func startMessageSocketEmptyMessageTimer(interval: Int) {
        stopMessageSocketEmptyMessageTimer()
        messageSocketEmptyMessageTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoManager.messageSocketEmptyMessageTimerFired),
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
private extension NicoManager {
    func startPingPongCheckTimer(interval: Int = pingPongCheckInterval) {
        stopPingPongCheckTimer()
        lastPongSocketDates = .init()
        pingPongCheckTimer = Timer.scheduledTimer(
            timeInterval: Double(interval),
            target: self,
            selector: #selector(NicoManager.pingPongCheckTimerFired),
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
            selector: #selector(NicoManager.pongCatchTimerFired),
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
private extension NicoManager {
    func setTextSocketEventCheckTimer(delay: Int) {
        guard isConnected else { return }
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        clearTextSocketEventCheckTimer()
        textSocketEventCheckTimer = Timer.scheduledTimer(
            timeInterval: Double(delay),
            target: self,
            selector: #selector(NicoManager.textSocketEventCheckTimerFired),
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
    var isNotStarted: Bool {
        [.beforeRelease, .released].contains(data.program.schedule.status)
    }

    func toLive(with nicoliveProgramId: String) -> Live {
        Live(
            liveProgramId: nicoliveProgramId,
            title: data.program.title,
            baseTime: data.program.schedule.vposBaseTime,
            openTime: data.program.schedule.openTime,
            beginTime: data.program.schedule.beginTime,
            isTimeShift: data.program.schedule.status == .ended,
            programProvider: data.programProvider.toProgramProvider()
        )
    }
}

private extension WatchProgramsResponse.ProgramProvider {
    func toProgramProvider() -> ProgramProvider {
        // "http://ch.nicovideo.jp/channel/ch2648853" -> "ch2648853"
        let providerId = String(profileUrl.absoluteString.split(separator: "/").last ?? "")
        log.debug(providerId)
        return ProgramProvider(
            // チャンネルは programProviderId が nil になるので、provide id を生成して使用する。
            programProviderId: programProviderId ?? providerId,
            name: name,
            profileUrl: profileUrl,
            // チャンネルは icons が nil になるので、適当に profileUrl を詰める。
            icons: icons?.toProgramProviderIcons() ?? ProgramProvider.Icons(
                uri150x150: profileUrl,
                uri50x50: profileUrl
            )
        )
    }
}

private extension WatchProgramsResponse.ProgramProvider.Icons {
    func toProgramProviderIcons() -> ProgramProvider.Icons {
        ProgramProvider.Icons(
            uri150x150: uri150x150,
            uri50x50: uri50x50
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
    func toChat(roomPosition: RoomPosition) -> Chat {
        Chat(
            roomPosition: roomPosition,
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
            }(),
            chatType: .other
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
