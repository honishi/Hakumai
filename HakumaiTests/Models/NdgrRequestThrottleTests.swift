import Foundation
import XCTest
import Alamofire
@testable import Hakumai

final class NdgrRequestThrottleTests: XCTestCase {
    func testDefaultPolicySpacesViewAndSegmentRequests() {
        let fixture = RecoveryFixture()
        var requestedAt: [TimeInterval] = []
        fixture.view = { count, _ in
            requestedAt.append(ProcessInfo.processInfo.systemUptime)
            return .ok(try RecoveryFixture.playlist(segment: count == 1 ? "first" : "end", next: count == 1 ? 100 : nil))
        }
        fixture.segment = { path in
            requestedAt.append(ProcessInfo.processInfo.systemUptime)
            return .ok(try path == "/end" ? RecoveryFixture.end() : RecoveryFixture.comment(id: "one", text: "one"))
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "頻度を抑えて履歴を取得")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init())
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(requestedAt.count, 4)
        for (previous, current) in zip(requestedAt, requestedAt.dropFirst()) {
            XCTAssertGreaterThanOrEqual(current - previous, 0.09)
        }
        XCTAssertEqual(recorder.comments, ["one"])
        manager.disconnect()
    }

    func testRetryAfterAcceptsSecondsAndHTTPDate() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(NdgrRequestThrottle.retryAfter("12", now: now), 12)
        XCTAssertEqual(NdgrRequestThrottle.retryAfter("Thu, 01 Jan 1970 00:00:30 GMT", now: now), 30)
        XCTAssertEqual(NdgrRequestThrottle.retryAfter("Wed, 31 Dec 1969 23:59:59 GMT", now: now), 0)
        XCTAssertNil(NdgrRequestThrottle.retryAfter("invalid"))
        XCTAssertNil(NdgrRequestThrottle.retryAfter("-1"))
        XCTAssertNil(NdgrRequestThrottle.retryAfter("inf"))
    }

    func testViewRateLimitRetriesSameURLWithoutReconnecting() {
        let fixture = RecoveryFixture()
        var requestedAt: [TimeInterval] = []
        fixture.view = { count, _ in
            requestedAt.append(ProcessInfo.processInfo.systemUptime)
            return count == 1 ? .http(429, headers: ["Retry-After": "1"]) : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "待機後に取得して正常終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [0.01]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 4)
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, fixture.beginAt])
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        if requestedAt.count == 2 { XCTAssertGreaterThanOrEqual(requestedAt[1] - requestedAt[0], 0.99) }
        XCTAssertTrue(recorder.logs.contains { $0.contains("待機終了") })
        manager.disconnect()
    }

    func testSegmentRateLimitPreservesHistoryAndWaitsBeforeNextView() {
        let fixture = RecoveryFixture()
        fixture.beginAt = "100"
        var calls = 0
        fixture.view = { count, _ in
            .ok(try RecoveryFixture.playlist(segment: count == 1 ? "history" : "end", next: count == 1 ? 200 : nil))
        }
        fixture.segment = { path in
            if path == "/end" { return .ok(try RecoveryFixture.end()) }
            calls += 1
            return calls == 1 ? .http(429) : .ok(try RecoveryFixture.comment(id: "one", text: "history"))
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "履歴を欠落させず終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [0.02]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(fixture.viewPositions, ["100", "200"])
        XCTAssertEqual(fixture.engines.count, 1)
        XCTAssertEqual(recorder.comments, ["history"])
        XCTAssertEqual(recorder.historySummaries, [1])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        manager.disconnect()
    }

    func testPersistentRateLimitStopsWithoutOuterRecovery() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .http(429) }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "429再試行上限")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [0.02, 0.04]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 3)
        XCTAssertEqual(fixture.viewPositions.count, 3)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        XCTAssertTrue(recorder.logs.contains { $0.contains("待機再試行上限2回") })
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了通知: 通信・解析失敗 HTTP 429: 待機再試行上限に到達") })
        manager.disconnect()
    }

    func testRateLimitDoesNotConsumeTimeoutRetry() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            if count == 1 { return .http(429) }
            if count == 2 { return .timeout }
            return .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "429後のタイムアウトもHTTP再試行で回復")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [0.01]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(fixture.viewPositions.count, 3)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        manager.disconnect()
    }

    func testConcurrentRateLimitsShareCooldownBudget() {
        let fixture = RecoveryFixture()
        fixture.beginAt = "100"
        fixture.view = { count, _ in
            if count == 1 {
                return .ok(try RecoveryFixture.playlist(segment: "first") + RecoveryFixture.playlist(segment: "second", next: 200))
            }
            return .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        var calls: [String: Int] = [:]
        fixture.segment = { path in
            if path == "/end" { return .ok(try RecoveryFixture.end()) }
            calls[path, default: 0] += 1
            if calls[path] == 1 { return .http(429) }
            return .ok(try RecoveryFixture.comment(id: path, text: path))
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "複数429を一度の待機で再試行")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [0.1]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(calls, ["/first": 2, "/second": 2])
        XCTAssertEqual(recorder.comments.sorted(), ["/first", "/second"])
        XCTAssertEqual(recorder.historySummaries, [2])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        XCTAssertEqual(fixture.programRequests, 1)
        manager.disconnect()
    }

    func testExcessiveRetryAfterStopsWithoutRetryingEarly() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .http(429, headers: ["Retry-After": "301"]) }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "長すぎる待機を中止")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 3)
        XCTAssertEqual(fixture.viewPositions.count, 1)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("待機上限を超過") })
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了通知: 通信・解析失敗 HTTP 429: サーバー指定の待機時間が上限を超過") })
        manager.disconnect()
    }

    func testManualStopDuringCooldownCancelsRetry() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .http(429) }
        let recorder = RecoveryRecorder()
        let stopped = expectation(description: "待機中に停止")
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [0.1]))
        recorder.onLog = { message in
            if message.contains("取得を一時停止") {
                DispatchQueue.main.async { manager.disconnect(); stopped.fulfill() }
            }
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [stopped], timeout: 3)
        let settled = expectation(description: "待機期限を経過")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertEqual(fixture.viewPositions.count, 1)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
    }

    func testEndSignalCancelsOtherSegmentsWaitingForRetry() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "limited") + RecoveryFixture.playlist(segment: "end"))
        }
        var limitedCalls = 0
        fixture.segment = { path in
            if path == "/limited" { limitedCalls += 1; return .http(429) }
            return .delayed(try RecoveryFixture.end(), 0.1)
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "429待機より放送終了を優先")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, endDrainTimeout: 0.1,
                                      throttlePolicy: .init(interval: 0, retryDelays: [30]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(limitedCalls, 1)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("取得を一時停止") })
        XCTAssertTrue(recorder.logs.contains { $0.contains("放送終了確認") })
        manager.disconnect()
    }

    func testWatchSocketEndDuringCooldownStopsImmediately() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .http(429) }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "WS放送終了を待機中にも受信")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0, retryDelays: [30]))
        recorder.onLog = { message in
            if message.contains("取得を一時停止") {
                fixture.engines.first?.delegate?.didReceive(event: .text(
                                                                "{\"type\":\"disconnect\",\"data\":{\"reason\":\"END_PROGRAM\"}}"))
            }
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(fixture.viewPositions.count, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        manager.disconnect()
    }

    func testPacingAndCooldownApplyToQueuedSegments() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "limited") + RecoveryFixture.playlist(segment: "end"))
        }
        var requestedAt: [(String, TimeInterval)] = []
        fixture.segment = { path in
            requestedAt.append((path, ProcessInfo.processInfo.systemUptime))
            return path == "/limited" ? .http(429) : .ok(try RecoveryFixture.end())
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "未送信のSegmentも429待機")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0.05, retryDelays: [0.2]))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertEqual(requestedAt.map { $0.0 }, ["/limited", "/end"])
        if requestedAt.count == 2 { XCTAssertGreaterThanOrEqual(requestedAt[1].1 - requestedAt[0].1, 0.19) }
        XCTAssertEqual(recorder.recoveryNotices, 0)
        manager.disconnect()
    }
}
