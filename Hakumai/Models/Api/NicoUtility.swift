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

// MARK: - Protocol
// note these functions are called in background thread, not main thread.
// so use explicit main thread for updating ui in these callbacks.
protocol NicoUtilityDelegate: AnyObject {
    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtilityType, user: User, live: Live)
    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtilityType, reason: String)
    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtilityType, roomPosition: RoomPosition)
    func nicoUtilityDidReceiveFirstChat(_ nicoUtility: NicoUtilityType, chat: Chat)
    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtilityType, chat: Chat)
    func nicoUtilityDidGetKickedOut(_ nicoUtility: NicoUtilityType)
    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidReceiveHeartbeat(_ nicoUtility: NicoUtilityType, heartbeat: Heartbeat)
}

protocol NicoUtilityType {
    // Properties
    static var shared: Self { get }
    var delegate: NicoUtilityDelegate? { get }
    var live: Live? { get }

    // Main Methods
    func connect(liveNumber: Int, connectType: NicoConnectType)
    func disconnect(reserveToReconnect: Bool)
    func comment(_ comment: String, anonymously: Bool, completion: @escaping (_ comment: String?) -> Void)

    // Methods for Community and Usernames
    func loadThumbnail(completion: @escaping (Data?) -> Void)
    func cachedUserName(forChat chat: Chat) -> String?
    func cachedUserName(forUserId userId: String) -> String?
    func resolveUsername(forUserId userId: String, completion: @escaping (String?) -> Void)
    func extractUsername(fromHtmlData htmlData: Data) -> String?

    // Utility Methods
    func urlString(forUserId userId: String) -> String
    func reserveToClearUserSessionCookie()

    // Miscellaneous Methods
    func reportAsNgUser(chat: Chat, completion: @escaping (_ userId: String?) -> Void)
}

// MARK: - Types
enum NicoConnectType {
    case chrome
    case safari
    case login(mail: String, password: String)
}

enum NicoUtilityError: Error {
    case network
    case `internal`
    case unknown
}

// MARK: - Constants
private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"
private let livePageUrl = "https://live.nicovideo.jp/watch/lv"
private let userPageUrl = "https://www.nicovideo.jp/user/"

// MARK: - WebSocket Messages
private let startWatchingMessage = """
{"type":"startWatching","data":{"stream":{"quality":"high","protocol":"hls","latency":"low","chasePlay":false},"room":{"protocol":"webSocket","commentable":true},"reconnect":false}}")
"""
private let pongMessage = """
{"type":"pong"}
"""
private let startThreadMessage = """
[{"ping":{"content":"rs:0"}},{"ping":{"content":"ps:0"}},{"thread":{"thread":"%@","version":"20061206","user_id":"guest","res_from":-150,"with_global":1,"scores":1,"nicoru":0}},{"ping":{"content":"pf:0"}},{"ping":{"content":"rf:0"}}]
"""
private let postCommentMessage = """
{"type":"postComment","data":{"text":"%@","vpos":%d,"isAnonymous":%@}}
"""

// MARK: - Class
final class NicoUtility: NicoUtilityType {
    // Public Properties
    static var shared: NicoUtility = NicoUtility()
    weak var delegate: NicoUtilityDelegate?
    private(set) var live: Live?

    // Private Properties
    private var lastLiveNumber: Int?
    private var userSessionCookie: String?
    private let session: Session
    private var managingSocket: WebSocket?
    private var messageSocket: WebSocket?
    private var isFirstChatReceived = false

    // Usernames
    private var cachedUserNames = [String: String]()

    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.headers.add(.userAgent(userAgent))
        self.session = Session(configuration: configuration)
    }
}

// MARK: - Public Methods (Main)
extension NicoUtility {
    func connect(liveNumber: Int, connectType: NicoConnectType) {
        let completion = { (userSessionCookie: String?) -> Void in
            self.connect(liveNumber: liveNumber, userSessionCookie: userSessionCookie)
        }
        switch connectType {
        case .chrome:
            CookieUtility.requestBrowserCookie(browserType: .chrome, completion: completion)
        case .safari:
            CookieUtility.requestBrowserCookie(browserType: .safari, completion: completion)
        case .login(let mail, let password):
            CookieUtility.requestLoginCookie(mailAddress: mail, password: password, completion: completion)
        }
    }

    func disconnect(reserveToReconnect: Bool = false) {
        managingSocket?.disconnect()
        messageSocket?.disconnect()
        reset()
        delegate?.nicoUtilityDidDisconnect(self)
    }

    func comment(_ comment: String, anonymously: Bool, completion: @escaping (String?) -> Void) {
        guard let baseTime = live?.baseTime else { return }
        let elapsed = Int(Date().timeIntervalSince1970) - Int(baseTime.timeIntervalSince1970)
        let vpos = elapsed * 100
        let message = String.init(
            format: postCommentMessage,
            comment, vpos, anonymously ? "true" : "false")
        log.debug(message)
        managingSocket?.write(string: message)
    }

    func urlString(forUserId userId: String) -> String {
        return userPageUrl + userId
    }

    func reserveToClearUserSessionCookie() {
        //
    }

    func loadThumbnail(completion: @escaping (Data?) -> Void) {
        guard let url = live?.community.thumbnailUrl else {
            completion(nil)
            return
        }
        session.request(url).responseData {
            switch $0.result {
            case .success(let data):
                completion(data)
            case .failure(_):
                completion(nil)
            }
        }
    }

    func reportAsNgUser(chat: Chat, completion: @escaping (String?) -> Void) {
        //
    }
}

// MARK: - Public Methods (Username)
extension NicoUtility {
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

        // XXX: Should we detect username resolving flood?

        let url = userPageUrl + String(userId)
        session.request(url).responseData { [weak self] in
            switch $0.result {
            case .success(let data):
                let username = self?.extractUsername(fromHtmlData: data)
                self?.cachedUserNames[userId] = username
                completion(username)
            case .failure(_):
                log.error("error in resolving username")
                completion(nil)
            }
        }
    }
}

// MARK: - Private Methods
private extension NicoUtility {
    func connect(liveNumber: Int, userSessionCookie: String?) {
        guard let userSessionCookie = userSessionCookie else {
            let reason = "No available cookie."
            log.error(reason)
            delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }

        self.userSessionCookie = userSessionCookie
        self.lastLiveNumber = liveNumber

        // TODO: use cookie

        delegate?.nicoUtilityWillPrepareLive(self)

        reqeustLiveInfo(lv: liveNumber) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let embeddedData):
                let live = embeddedData.toLive()
                self?.live = live
                // TODO: user
                let user = User()
                me.delegate?.nicoUtilityDidPrepareLive(me, user: user, live: live)
                me.openManagingSocket(webSocketUrl: embeddedData.site.relive.webSocketUrl)
            case .failure(_):
                let reason = "Failed to load live info."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason)
            }
        }
    }

    func reqeustLiveInfo(lv: Int, completion: @escaping (Result<EmbeddedDataProperties, NicoUtilityError>) -> Void) {
        let url = livePageUrl + "\(lv)"
        let request = session.request(url)
        request.cURLDescription(calling: { log.debug($0) })
        request.responseData {
            log.debug($0.debugDescription)
            switch $0.result {
            case .success(let data):
                guard let embedded = NicoUtility.extractEmbeddedDataPropertiesFromLivePage(html: data) else {
                    completion(Result.failure(NicoUtilityError.internal))
                    return
                }
                completion(Result.success(embedded))
            case .failure(_):
                completion(Result.failure(NicoUtilityError.internal))
            }
        }
    }

    func openManagingSocket(webSocketUrl: String) {
        openManagingSocket(webSocketUrl: webSocketUrl) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let room):
                me.openMessageSocket(room: room)
            case .failure(_):
                let reason = "Failed to load message server info."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason)
            }
        }
    }

    func openMessageSocket(room: WebSocketRoomData) {
        openMessageSocket(room: room) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success():
                me.delegate?.nicoUtilityDidConnectToLive(me, roomPosition: RoomPosition.arena)
            case .failure(_):
                let reason = "Failed to open message server."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason)
            }
        }
    }

    func reset() {
        live = nil
        // user = nil
        managingSocket = nil
        messageSocket = nil
        isFirstChatReceived = false
    }
}

// MARK: Private Methods (Managing Socket)
private extension NicoUtility {
    func openManagingSocket(webSocketUrl: String, completion: @escaping (Result<WebSocketRoomData, NicoUtilityError>) -> Void) {
        guard let url = URL(string: webSocketUrl) else {
            completion(Result.failure(NicoUtilityError.internal))
            return
        }
        var request = URLRequest(url: url)
        request.headers = ["User-Agent": userAgent]
        request.timeoutInterval = 10
        let socket = WebSocket(request: request)
        socket.onEvent = { [weak self] in
            self?.handleManagingSocketEvent(
                socket: socket,
                event: $0,
                completion: completion)
        }
        socket.connect()
        managingSocket = socket
    }

    func handleManagingSocketEvent(socket: WebSocket, event: WebSocketEvent, completion: (Result<WebSocketRoomData, NicoUtilityError>) -> Void) {
        switch event {
        case .connected(_):
            log.debug("connected")
            socket.write(string: startWatchingMessage)
        case .disconnected(_, _):
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            processWebSocketData(text: text, socket: socket, completion: completion)
        case .binary(_):
            log.debug("binary")
        case .pong(_):
            log.debug("pong")
        case .ping(_):
            log.debug("ping")
        case .error(_):
            log.debug("error")
        case .viabilityChanged(_):
            log.debug("viabilityChanged")
        case .reconnectSuggested(_):
            log.debug("reconnectSuggested")
        case .cancelled:
            log.debug("cancelled")
        }
    }

    func processWebSocketData(text: String, socket: WebSocket, completion: (Result<WebSocketRoomData, NicoUtilityError>) -> Void) {
        guard let decoded = decodeWebSocketData(text: text) else { return }
        switch decoded {
        case let room as WebSocketRoomData:
            log.debug(room)
            completion(Result.success(room))
        case is WebSocketPingData:
            socket.write(string: pongMessage)
        case let stat as WebSocketStatisticsData:
            delegate?.nicoUtilityDidReceiveHeartbeat(self, heartbeat: stat.toHeartbeat())
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
        case .room:
            return try? decoder.decode(WebSocketRoomData.self, from: data)
        case .statistics:
            return try? decoder.decode(WebSocketStatisticsData.self, from: data)
        }
    }
}

// MARK: - Private Methods (Message Socket)
private extension NicoUtility {
    func openMessageSocket(room: WebSocketRoomData, completion: @escaping (Result<Void, NicoUtilityError>) -> Void) {
        guard let url = URL(string: room.data.messageServer.uri) else {
            completion(Result.failure(NicoUtilityError.internal))
            return
        }
        var request = URLRequest(url: url)
        request.headers = [
            "User-Agent": userAgent,
            "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
            "Sec-WebSocket-Protocol": "msg.nicovideo.jp#json"
        ]
        request.timeoutInterval = 10
        let socket = WebSocket(request: request)
        socket.onEvent = { [weak self] in
            self?.handleMessageSocketEvent(
                socket: socket,
                event: $0,
                room: room,
                completion: completion)
        }
        socket.connect()
        messageSocket = socket
    }

    func handleMessageSocketEvent(socket: WebSocket, event: WebSocketEvent, room: WebSocketRoomData, completion: (Result<Void, NicoUtilityError>) -> Void) {
        switch event {
        case .connected(_):
            log.debug("connected")
            completion(Result.success(()))
            sendStartThreadMessage(socket: socket, room: room)
        case .disconnected(_, _):
            log.debug("disconnected")
        case .text(let text):
            log.debug("text: \(text)")
            decodeChat(text: text)
        case .binary(_):
            log.debug("binary")
        case .pong(_):
            log.debug("pong")
        case .ping(_):
            log.debug("ping")
        case .error(_):
            log.debug("error")
        case .viabilityChanged(_):
            log.debug("viabilityChanged")
        case .reconnectSuggested(_):
            log.debug("reconnectSuggested")
        case .cancelled:
            log.debug("cancelled")
        }
    }

    func sendStartThreadMessage(socket: WebSocket, room: WebSocketRoomData) {
        let message = String.init(format: startThreadMessage, room.data.threadId)
        socket.write(string: message)
    }

    func decodeChat(text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let chat = try? decoder.decode(WebSocketChatData.self, from: data) else { return }
        log.debug(chat)
        if isFirstChatReceived {
            delegate?.nicoUtilityDidReceiveChat(self, chat: chat.toChat())
        } else {
            delegate?.nicoUtilityDidReceiveFirstChat(self, chat: chat.toChat())
            isFirstChatReceived = true
        }
    }
}

// MARK: - Private Utility Methods
private extension NicoUtility {
    func customHeaders() -> [String: String] {
        return [:]
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
}

private extension WebSocketChatData {
    func toChat() -> Chat {
        let chat = Chat()
        chat.internalNo = self.chat.no
        // TODO: ?
        chat.roomPosition = .arena
        chat.no = self.chat.no
        chat.date = self.chat.date.toDateAsTimeIntervalSince1970()
        chat.dateUsec = self.chat.dateUsec
        if let mail = self.chat.mail {
            chat.mail = [mail]
        }
        chat.userId = self.chat.userId
        if let premium = self.chat.premium {
            chat.premium = Premium(rawValue: premium)
        } else {
            chat.premium = .ippan
        }
        chat.comment = self.chat.content
        chat.score = 0
        return chat
    }
}

private extension WebSocketStatisticsData {
    func toHeartbeat() -> Heartbeat {
        let hb = Heartbeat()
        hb.status = .ok
        hb.watchCount = data.viewers
        hb.commentCount = data.comments
        return hb
    }
}
