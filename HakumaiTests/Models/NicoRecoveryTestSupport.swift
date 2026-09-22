import Foundation
import XCTest
import Alamofire
import Starscream
import SwiftProtobuf
@testable import Hakumai

// 実際の接続処理をテストするための API・WebSocket・NDGR 応答。
final class RecoveryFixture {
    enum Reply {
        case ok(Data), holding(Data), delayed(Data, TimeInterval), timeout
        case http(Int, headers: [String: String] = [:])
        case delayedFailure(URLError.Code, TimeInterval)
        case chunks([Data], TimeInterval)
        case awaitingHeaders
    }
    var beginAt = String(Int(Date().timeIntervalSince1970) - 10)
    var status: (Int) -> String = { _ in "ON_AIR" }
    var programFailure: (Int) -> Int? = { _ in nil }
    var view: (Int, URL) throws -> Reply = { _, _ in .ok(Data()) }
    var segment: (String) throws -> Reply = { _ in .ok(Data()) }
    var sendMessageServer = true
    private(set) var programRequests = 0
    private(set) var viewPositions: [String] = []
    var engines: [RecoveryEngine] = []

    func manager(recorder: RecoveryRecorder, delays: [TimeInterval] = [0, 0, 0],
                 ndgrClient: NdgrClientType? = nil, endDrainTimeout: TimeInterval = 5,
                 throttlePolicy: NdgrRequestThrottle.Policy = .init(interval: 0),
                 timeoutPolicy: NdgrStreamTimeout.Policy = .init()) -> NicoManager {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecoveryURLProtocol.self]
        RecoveryURLProtocol.reply = { [self] url in try respond(url) }
        let manager = NicoManager(authManager: RecoveryAuth(), ndgrClient: ndgrClient ?? NdgrClient(configuration: config, endDrainTimeout: endDrainTimeout, throttlePolicy: throttlePolicy, timeoutPolicy: timeoutPolicy),
                                  configuration: config, recoveryDelays: delays) { [self] request in
            let engine = RecoveryEngine(sendMessageServer: sendMessageServer)
            engines.append(engine)
            return WebSocket(request: request, engine: engine)
        }
        manager.delegate = recorder
        return manager
    }

    private func respond(_ url: URL) throws -> Reply {
        switch url.path {
        case "/api/v1/watch/programs":
            programRequests += 1
            if let status = programFailure(programRequests) { return .http(status) }
            let time = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: try XCTUnwrap(Double(beginAt))))
            return .ok(Data("""
            {"meta":{"status":200},"data":{"program":{"title":"test","description":"", "schedule":{
            "beginTime":"\(time)","endTime":"\(time)","openTime":"\(time)","scheduledEndTime":"\(time)",
            "status":"\(status(programRequests))","vposBaseTime":"\(time)"}},
            "programProvider":{"name":"test","profileUrl":"https://example.invalid/user/1","type":"user"}}}
            """.utf8))
        case "/open_id/userinfo":
            return .ok(Data("""
            {"sub":"1","nickname":"test","profile":"https://example.invalid/1", "picture":"https://example.invalid/icon", "gender":"", "zoneinfo":"", "updatedAt":0}
            """.utf8))
        case "/api/v1/wsendpoint":
            return .ok(Data("""
            {"meta":{"status":200},"data":{"url":"wss://recovery.invalid/watch"}}
            """.utf8))
        case "/view":
            let position = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "at" }?.value ?? ""
            viewPositions.append(position)
            return try view(viewPositions.count, url)
        default: return try segment(url.path)
        }
    }

    static func playlist(segment: String, next: Int64? = nil) throws -> Data {
        var entry = Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry()
        entry.segment.uri = "https://recovery.invalid/\(segment)"
        var data = try frame(entry)
        if let next = next {
            var marker = Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry()
            marker.next.at = next
            data += try frame(marker)
        }
        return data
    }

    static func comment(id: String, text: String) throws -> Data {
        var message = Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage()
        message.meta.id = id
        message.message.chat.content = text
        message.message.chat.rawUserID = 1
        return try frame(message)
    }

    static func end() throws -> Data {
        var message = Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage()
        message.state.programStatus.state = .ended
        return try frame(message)
    }

    private static func frame<T: SwiftProtobuf.Message>(_ message: T) throws -> Data {
        let bytes = try message.serializedData()
        var size = bytes.count
        var data = Data()
        repeat {
            data.append(UInt8(size & 0x7f) | (size > 127 ? 0x80 : 0))
            size >>= 7
        } while size > 0
        data += bytes
        return data
    }
}

private final class RecoveryURLProtocol: URLProtocol {
    static var reply: ((URL) throws -> RecoveryFixture.Reply)?
    private var stopped = false
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        DispatchQueue.main.async { [self] in
            guard !stopped, let url = request.url else { return }
            do {
                guard let reply = try Self.reply?(url) else { return }
                try deliver(reply)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    private func deliver(_ reply: RecoveryFixture.Reply) throws {
        switch reply {
        case .awaitingHeaders:
            break
        case .timeout:
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
        case .delayedFailure(let code, let delay):
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                guard !stopped else { return }
                client?.urlProtocol(self, didFailWithError: URLError(code))
            }
        case .http(let code, let headers):
            try sendResponse(status: code, headers: headers)
            sendData(Data(), finish: true)
        case .ok(let data):
            try sendResponse()
            sendData(data, finish: true)
        case .holding(let data):
            try sendResponse()
            sendData(data, finish: false)
        case .delayed(let data, let delay):
            try sendResponse()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.sendData(data, finish: true) }
        case .chunks(let chunks, let interval):
            try sendResponse()
            sendChunks(chunks, interval: interval)
        }
    }

    private func sendChunks(_ chunks: [Data], interval: TimeInterval) {
        if chunks.isEmpty { sendData(Data(), finish: true) }
        for (index, data) in chunks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index + 1) * interval) {
                self.sendData(data, finish: index == chunks.count - 1)
            }
        }
    }

    private func sendResponse(status: Int = 200, headers: [String: String] = [:]) throws {
        let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil,
                                                     headerFields: headers.merging(["Content-Type": "application/octet-stream"]) { first, _ in first }))
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    private func sendData(_ data: Data, finish: Bool) {
        guard !stopped else { return }
        if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
        if finish { client?.urlProtocolDidFinishLoading(self) }
    }

    override func stopLoading() { DispatchQueue.main.async { self.stopped = true } }
}

final class RecoveryEngine: Engine {
    weak var delegate: EngineDelegate?
    let responds: Bool
    init(sendMessageServer: Bool) { responds = sendMessageServer }
    func register(delegate: EngineDelegate) { self.delegate = delegate }
    func start(request: URLRequest) {
        delegate?.didReceive(event: .connected([:]))
        if responds { sendMessageServer() }
    }
    func sendMessageServer() {
        delegate?.didReceive(event: .text("""
        {"type":"messageServer","data":{"viewUri":"https://recovery.invalid/view", "vposBaseTime":"2026-09-21T00:00:00Z", "hashedUserId":"test"}}
        """))
    }
    func stop(closeCode: UInt16) { delegate?.didReceive(event: .disconnected("", closeCode)) }
    func forceStop() {}
    func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) { completion?() }
    func write(string: String, completion: (() -> Void)?) { completion?() }
}

private struct RecoveryAuth: AuthManagerProtocol {
    var authWebUrl: URL { URL(fileURLWithPath: "/unused-auth") }
    var hasToken: Bool { true }
    var currentToken: AuthManagerToken? {
        AuthManagerToken(accessToken: "test", tokenType: "Bearer", expiresIn: 3600, scope: "", refreshToken: "test", idToken: nil)
    }
    func extractCallbackResponseAndSaveToken(response: String, completion: (Result<AuthManagerToken, AuthManagerError>) -> Void) {}
    func refreshToken(completion: @escaping (Result<AuthManagerToken, AuthManagerError>) -> Void) { completion(.failure(.refreshTokenFailed)) }
    func clearToken() {}
    func injectExpiredAccessToken() {}
}

final class RecoveryRecorder: NicoManagerDelegate {
    var comments: [String] = []
    var logs: [String] = []
    var disconnections: [NicoDisconnectContext] = []
    var onDisconnect: ((NicoDisconnectContext) -> Void)?
    var onLog: ((String) -> Void)?
    var historySummaries: [Int] = []
    var historyBatchCount = 0
    var initialHistoryFlags: [Bool] = []
    var recoveryNotices = 0
    var rateLimitWaitNotices = 0
    var preparationFailures = 0
    var onPreparationFailure: (() -> Void)?
    func nicoManagerNeedsToken(_ nicoManager: NicoManagerType) {}
    func nicoManagerDidConfirmTokenExistence(_ nicoManager: NicoManagerType) {}
    func nicoManagerWillPrepareLive(_ nicoManager: NicoManagerType) {}
    func nicoManagerDidPrepareLive(_ nicoManager: NicoManagerType, user: User, live: Live, connectContext: NicoConnectContext) {}
    func nicoManagerDidFailToPrepareLive(_ nicoManager: NicoManagerType, error: NicoError) {
        preparationFailures += 1
        onPreparationFailure?()
    }
    func nicoManagerDidConnectToLive(_ nicoManager: NicoManagerType, roomPosition: RoomPosition, connectContext: NicoConnectContext) {}
    func nicoManagerDidReceiveChat(_ nicoManager: NicoManagerType, chat: Chat) { comments.append(chat.comment) }
    func nicoManagerWillReconnectToLive(_ nicoManager: NicoManagerType, reason: NicoReconnectReason) { recoveryNotices += 1 }
    func nicoManagerWillWaitForRateLimit(_ nicoManager: NicoManagerType) {
        XCTAssertTrue(Thread.isMainThread)
        rateLimitWaitNotices += 1
    }
    func nicoManagerDidReceiveStatistics(_ nicoManager: NicoManagerType, stat: LiveStatistics) {}
    func nicoManagerReceivingChatHistory(_ nicoManager: NicoManagerType, requestCount: Int, totalChatCount: Int) {}
    func nicoManagerDidReceiveChatHistory(_ nicoManager: NicoManagerType, chats: [Chat], isInitial: Bool) {
        comments += chats.map(\.comment)
        historyBatchCount += 1
        initialHistoryFlags.append(isInitial)
    }
    func nicoManagerDidFinishChatHistory(_ nicoManager: NicoManagerType, totalChatCount: Int) {
        historySummaries.append(totalChatCount)
    }
    func nicoManagerDidDisconnect(_ nicoManager: NicoManagerType, disconnectContext: NicoDisconnectContext) {
        disconnections.append(disconnectContext)
        onDisconnect?(disconnectContext)
    }
    func nicoManager(_ nicoManager: NicoManagerType, hasDebugMessgae message: String) {
        logs.append(message)
        onLog?(message)
    }
}

final class RecoveryNDGRStub: NdgrClientType {
    weak var delegate: NdgrClientDelegate?
    var connections: [ConnectionDiagnostics] = []
    var onConnect: ((ConnectionDiagnostics) -> Void)?
    func connect(viewUri: URL, beginTime: Date, diagnostics: ConnectionDiagnostics, resuming: Bool) {
        connections.append(diagnostics)
        delegate?.ndgrClientDidConnect(self, diagnostics: diagnostics)
        onConnect?(diagnostics)
    }
    func disconnect() {}
}
