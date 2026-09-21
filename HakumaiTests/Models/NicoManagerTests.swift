//
//  NicoManagerTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/14/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest
import Alamofire
import Starscream
import SwiftProtobuf
@testable import Hakumai

private let kAsyncTimeout: TimeInterval = 3

final class NicoManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - User Account
    func testUserIcon() {
        let nicoManager: NicoManagerType = NicoManager()
        var expected: String? = ""
        var actual: String? = ""

        expected = nil
        actual = nicoManager.userIconUrl(for: "XXX")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/0/2.jpg"
        actual = nicoManager.userIconUrl(for: "2")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/0/9005.jpg"
        actual = nicoManager.userIconUrl(for: "9005")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/9/99998.jpg"
        actual = nicoManager.userIconUrl(for: "99998")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/1/12346.jpg"
        actual = nicoManager.userIconUrl(for: "12346")?.absoluteString
        XCTAssert(actual == expected)

        expected = "https://secure-dcdn.cdn.nimg.jp/nicoaccount/usericon/25/252346.jpg"
        actual = nicoManager.userIconUrl(for: "252346")?.absoluteString
        XCTAssert(actual == expected)
    }
}

// 実際の API → WS → NDGR 経路をローカルの応答で再現する。

extension NicoManagerTests {
    func testViewTimeoutTwiceRefreshesEndpointResumesAndDoesNotDuplicateComments() throws {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            if count == 2 || count == 3 { return .timeout }
            let segment = count == 1 ? "first" : "recovered"
            return .ok(try RecoveryFixture.playlist(segment: segment, next: count == 1 ? 100 : nil))
        }
        fixture.segment = { path in
            var data = try RecoveryFixture.comment(id: "one", text: "first")
            if path == "/recovered" {
                data += try RecoveryFixture.comment(id: "two", text: "second")
                data += try RecoveryFixture.end()
            }
            return .ok(data)
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "放送終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["first", "second"])
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, "100", "100", "100"])
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧成功") })
        XCTAssertFalse(recorder.disconnections.contains { if case .failure = $0 { return true }; return false })
        manager.disconnect()
    }

    func testProgramEndStopsEvenWhenViewAndSegmentHTTPHaveNotClosed() throws {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .holding(try RecoveryFixture.playlist(segment: "end")) }
        fixture.segment = { _ in .holding(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "EOFを待たず終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
        manager.disconnect()
    }

    func testMissingNextChecksProgramStatusAndStopsWhenEnded() {
        let fixture = RecoveryFixture()
        fixture.status = { $0 == 1 ? "ON_AIR" : "ENDED" }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "APIで放送終了確認")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(fixture.engines.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("番組情報で放送終了を確認") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧成功") })
    }

    func testEmptyLiveStreamHasBoundedRecoveryAndEndsAsFailure() {
        let fixture = RecoveryFixture()
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "上限で停止")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder, delays: [0, 0])
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 3)
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧断念") })
        XCTAssertFalse(recorder.disconnections.contains { if case .normal = $0 { return true }; return false })
    }

    func testTimeshiftEOFStopsWithoutRecovery() {
        let fixture = RecoveryFixture()
        fixture.status = { _ in "ENDED" }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "タイムシフト完了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 1)
    }

    func testPermissionErrorDoesNotRecoverOrReportProgramEnd() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .http(403) }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "権限エラーで停止")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
    }

    func testStopCancelsScheduledRecovery() {
        let fixture = RecoveryFixture()
        let recorder = RecoveryRecorder()
        let stopped = expectation(description: "手動停止")
        let noRestart = expectation(description: "再接続しない")
        noRestart.isInverted = true
        let manager = fixture.manager(recorder: recorder, delays: [0.05])
        recorder.onLog = { message in
            if message.contains("復旧開始") {
                DispatchQueue.main.async { manager.disconnect(); stopped.fulfill() }
            }
            if message.contains("復旧試行を開始") { noRestart.fulfill() }
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [stopped], timeout: 5)
        wait(for: [noRestart], timeout: 0.15)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧予約を取り消す") })
    }

    func testTransientAPIFailureDuringRecoveryRetriesAndThenConfirmsEnd() {
        let fixture = RecoveryFixture()
        fixture.status = { $0 == 1 ? "ON_AIR" : "ENDED" }
        fixture.programFailure = { $0 == 2 ? 503 : nil }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "API障害後終了確認")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 3)
        XCTAssertTrue(recorder.logs.contains { $0.contains("接続準備中の通信失敗") })
    }

    func testStopDuringWSSetupIgnoresLateMessageServer() {
        let fixture = RecoveryFixture()
        fixture.sendMessageServer = false
        let recorder = RecoveryRecorder()
        let stopped = expectation(description: "WS待機中停止")
        let noData = expectation(description: "停止後NDGR開始なし")
        noData.isInverted = true
        let manager = fixture.manager(recorder: recorder)
        recorder.onLog = { message in
            if message.contains("視聴用WS: 接続成功") {
                DispatchQueue.main.async {
                    manager.disconnect()
                    fixture.engines.first?.sendMessageServer()
                    stopped.fulfill()
                }
            }
            if message.contains("NDGR開始 (") { noData.fulfill() }
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [stopped], timeout: 5)
        wait(for: [noData], timeout: 0.1)
        XCTAssertTrue(fixture.viewPositions.isEmpty)
    }

    func testSingleHTTPRetryRecoversWithoutReopeningWatchSocket() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            count == 1 ? .timeout : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "HTTP再試行で回復後終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.engines.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("HTTP再試行で回復") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
    }

    func testSegmentFailureDoesNotSkipUnfinishedViewPosition() {
        let fixture = RecoveryFixture()
        var segmentRequests = 0
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "segment", next: 999)) }
        fixture.segment = { _ in
            segmentRequests += 1
            return segmentRequests < 3 ? .timeout : .ok(try RecoveryFixture.end())
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "Segmentを再取得後終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, fixture.beginAt])
    }

    func testServerEndProgramDisconnectStopsWithoutRecovery() {
        let fixture = RecoveryFixture()
        fixture.sendMessageServer = false
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "WS放送終了通知")
        let manager = fixture.manager(recorder: recorder)
        recorder.onLog = { message in
            if message.contains("視聴用WS: 接続成功") {
                fixture.engines.first?.delegate?.didReceive(event: .text(
                                                                "{\"type\":\"disconnect\",\"data\":{\"reason\":\"END_PROGRAM\"}}"))
            }
        }
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
    }

    func testSwitchingProgramsIgnoresOldNDGREndNotification() {
        let fixture = RecoveryFixture()
        let recorder = RecoveryRecorder()
        let stub = RecoveryNDGRStub()
        let switched = expectation(description: "新しい番組に接続")
        let manager = fixture.manager(recorder: recorder, ndgrClient: stub)
        stub.onConnect = { _ in
            if stub.connections.count == 1 {
                DispatchQueue.main.async { manager.connect(liveProgramId: "lv2") }
            } else {
                let count = recorder.disconnections.count
                manager.ndgrClientDidDisconnect(stub, diagnostics: stub.connections[0], reason: .programEnded)
                XCTAssertEqual(recorder.disconnections.count, count)
                XCTAssertEqual(manager.live?.liveProgramId, "lv2")
                switched.fulfill()
            }
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [switched], timeout: 5)
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了通知を無視: 古い接続") })
        manager.disconnect()
    }

    func testCompletedHistoryIsNotLostWhenWatchConnectionRestarts() {
        let fixture = RecoveryFixture()
        fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
        var requestRecovery: () -> Void = {}
        fixture.view = { count, _ in
            if count == 2 {
                DispatchQueue.main.async { requestRecovery() }
                return .holding(Data())
            }
            return .ok(try RecoveryFixture.playlist(segment: count == 1 ? "history" : "end", next: count == 1 ? 100 : nil))
        }
        fixture.segment = { path in
            .ok(try path == "/history" ? RecoveryFixture.comment(id: "history", text: "history") : RecoveryFixture.end())
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "履歴を保って再接続後終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        requestRecovery = { manager.reconnect(reason: .normal) }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["history"])
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, "100", "100"])
        XCTAssertTrue(recorder.logs.contains { $0.contains("旧コメントWSの空送信・Ping監視タイマーは起動しない") })
    }

    func testRecoveryPolicyRetriesTransientFailuresOnly() {
        for code in [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet] {
            XCTAssertTrue(NicoRecoveryPolicy.shouldRetry(URLError(URLError.Code(rawValue: code))))
        }
        XCTAssertFalse(NicoRecoveryPolicy.shouldRetry(URLError(.cancelled)))
        XCTAssertFalse(NicoRecoveryPolicy.shouldRetry(CancellationError()))
        for status in [429, 500, 502, 503, 504] {
            XCTAssertTrue(NicoRecoveryPolicy.shouldRetry(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: status))))
        }
        for status in [400, 401, 403, 404] {
            XCTAssertFalse(NicoRecoveryPolicy.shouldRetry(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: status))))
        }
    }
}

private final class RecoveryFixture {
    enum Reply {
        case ok(Data), holding(Data), http(Int), timeout
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
                 ndgrClient: NdgrClientType? = nil) -> NicoManager {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecoveryURLProtocol.self]
        RecoveryURLProtocol.reply = { [self] url in try respond(url) }
        let manager = NicoManager(authManager: RecoveryAuth(), ndgrClient: ndgrClient ?? NdgrClient(configuration: config),
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
                let status: Int
                let data: Data
                let finish: Bool
                switch reply {
                case .timeout:
                    client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
                    return
                case .http(let code): (status, data, finish) = (code, Data(), true)
                case .ok(let bytes): (status, data, finish) = (200, bytes, true)
                case .holding(let bytes): (status, data, finish) = (200, bytes, false)
                }
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                                             headerFields: ["Content-Type": "application/octet-stream"]))
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
                if finish { client?.urlProtocolDidFinishLoading(self) }
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    override func stopLoading() { DispatchQueue.main.async { self.stopped = true } }
}

private final class RecoveryEngine: Engine {
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

private final class RecoveryRecorder: NicoManagerDelegate {
    var comments: [String] = []
    var logs: [String] = []
    var disconnections: [NicoDisconnectContext] = []
    var onDisconnect: ((NicoDisconnectContext) -> Void)?
    var onLog: ((String) -> Void)?
    func nicoManagerNeedsToken(_ nicoManager: NicoManagerType) {}
    func nicoManagerDidConfirmTokenExistence(_ nicoManager: NicoManagerType) {}
    func nicoManagerWillPrepareLive(_ nicoManager: NicoManagerType) {}
    func nicoManagerDidPrepareLive(_ nicoManager: NicoManagerType, user: User, live: Live, connectContext: NicoConnectContext) {}
    func nicoManagerDidFailToPrepareLive(_ nicoManager: NicoManagerType, error: NicoError) {}
    func nicoManagerDidConnectToLive(_ nicoManager: NicoManagerType, roomPosition: RoomPosition, connectContext: NicoConnectContext) {}
    func nicoManagerDidReceiveChat(_ nicoManager: NicoManagerType, chat: Chat) { comments.append(chat.comment) }
    func nicoManagerWillReconnectToLive(_ nicoManager: NicoManagerType, reason: NicoReconnectReason) {}
    func nicoManagerDidReceiveStatistics(_ nicoManager: NicoManagerType, stat: LiveStatistics) {}
    func nicoManagerReceivingChatHistory(_ nicoManager: NicoManagerType, requestCount: Int, totalChatCount: Int) {}
    func nicoManagerDidReceiveChatHistory(_ nicoManager: NicoManagerType, chats: [Chat]) { comments += chats.map(\.comment) }
    func nicoManagerDidDisconnect(_ nicoManager: NicoManagerType, disconnectContext: NicoDisconnectContext) {
        disconnections.append(disconnectContext)
        onDisconnect?(disconnectContext)
    }
    func nicoManager(_ nicoManager: NicoManagerType, hasDebugMessgae message: String) {
        logs.append(message)
        onLog?(message)
    }
}

private final class RecoveryNDGRStub: NdgrClientType {
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
