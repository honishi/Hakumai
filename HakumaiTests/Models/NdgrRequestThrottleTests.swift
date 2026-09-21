import Foundation
import XCTest
import Alamofire
@testable import Hakumai

final class NdgrRequestThrottleTests: XCTestCase {
    func testDefaultPolicySpacesViewAndSegmentRequests() {
        XCTAssertEqual(NdgrRequestThrottle.Policy().interval, 0.01)
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
            XCTAssertGreaterThanOrEqual(current - previous, 0.007)
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
        let metrics = recorder.logs.filter { $0.contains("NDGR取得集計: 取得停止") }
        XCTAssertEqual(metrics.count, 1)
        XCTAssertTrue(metrics.first?.contains("HTTP送信許可=3件") == true)
        XCTAssertGreaterThanOrEqual(metric("429待機", in: metrics.first ?? ""), 0.95)
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

extension NdgrRequestThrottleTests {
    func testStableResponsesRestoreSpeedWithoutResettingRetryBudget() {
        let fixture = historyFixture(viewFailures: [1, 6], totalViews: 7)
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "速度回復しても429上限は維持")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let policy = NdgrRequestThrottle.Policy(interval: 0.01, retryDelays: [0.04],
                                                stableDuration: 0.025, stableResponseCount: 3)
        let manager = fixture.manager(recorder: recorder, throttlePolicy: policy)
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 3)
        let recoveries = recorder.logs.filter { $0.contains("NDGR取得速度を回復") }
        XCTAssertEqual(recoveries.count, 1)
        XCTAssertTrue(recoveries.first?.contains("0.02→0.01秒") == true)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(fixture.viewPositions.count, 6)
        XCTAssertEqual(recorder.comments, ["2", "3", "4", "5"])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("初回履歴取得: 完了通知前に終了") })
        manager.disconnect()
    }

    func testSpeedRecoveryRequiresBothDurationAndResponseCount() {
        let policies = [
            NdgrRequestThrottle.Policy(interval: 0.005, retryDelays: [0.01], stableDuration: 30, stableResponseCount: 1),
            NdgrRequestThrottle.Policy(interval: 0.005, retryDelays: [0.01], stableDuration: 0, stableResponseCount: 100)
        ]
        for policy in policies {
            let fixture = historyFixture(viewFailures: [1], totalViews: 4)
            let recorder = RecoveryRecorder()
            let ended = expectation(description: "速度回復条件が未成立")
            recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
            let manager = fixture.manager(recorder: recorder, throttlePolicy: policy)
            manager.connect(liveProgramId: "lv1")
            wait(for: [ended], timeout: 3)
            XCTAssertFalse(recorder.logs.contains { $0.contains("NDGR取得速度を回復") })
            manager.disconnect()
        }
    }

    func testTimeoutResetsSpeedRecoveryProgress() {
        let fixture = historyFixture(viewFailures: [1], totalViews: 4)
        let view = fixture.view
        fixture.view = { count, url in count == 3 ? .timeout : try view(count, url) }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "通信失敗後は安定性を数え直す")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let policy = NdgrRequestThrottle.Policy(interval: 0.005, retryDelays: [0.01], stableDuration: 0, stableResponseCount: 3)
        let manager = fixture.manager(recorder: recorder, throttlePolicy: policy)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        XCTAssertFalse(recorder.logs.contains { $0.contains("NDGR取得速度を回復") })
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(fixture.viewPositions.count, 4)
        manager.disconnect()
    }

    func testHistoryCompletionReportsMetricsAndElapsedTimeOnce() {
        let fixture = RecoveryFixture()
        fixture.beginAt = "100"
        fixture.view = { count, _ in
            if count == 1 {
                return .ok(try RecoveryFixture.playlist(segment: "history", next: Int64(Date().timeIntervalSince1970)))
            }
            return .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { path in
            .ok(try path == "/end" ? RecoveryFixture.end() : RecoveryFixture.comment(id: "history", text: "history"))
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "履歴完了の計測")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(interval: 0.03))
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 3)
        let historyMetrics = recorder.logs.filter { $0.contains("NDGR取得集計: 履歴取得完了") }
        XCTAssertEqual(historyMetrics.count, 1)
        XCTAssertTrue(historyMetrics.first?.contains("HTTP送信許可=2件") == true)
        XCTAssertGreaterThan(metric("速度制限待機", in: historyMetrics.first ?? ""), 0.01)
        XCTAssertEqual(metric("429待機", in: historyMetrics.first ?? ""), 0)
        XCTAssertEqual(recorder.logs.filter { $0.contains("初回履歴取得:") }.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("初回履歴取得: 完了, 総時間=") })
        XCTAssertEqual(recorder.comments, ["history"])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        manager.disconnect()
    }

    private func historyFixture(viewFailures: Set<Int>, totalViews: Int) -> RecoveryFixture {
        let fixture = RecoveryFixture()
        fixture.beginAt = "100"
        fixture.view = { count, _ in
            if viewFailures.contains(count) { return .http(429) }
            return .ok(try RecoveryFixture.playlist(segment: count == totalViews ? "end" : String(count), next: Int64(100 + count)))
        }
        fixture.segment = { path in
            let id = String(path.dropFirst())
            return .ok(try path == "/end" ? RecoveryFixture.end() : RecoveryFixture.comment(id: id, text: id))
        }
        return fixture
    }

    private func metric(_ name: String, in log: String) -> Double {
        guard let suffix = log.components(separatedBy: "\(name)=").dropFirst().first,
              let value = Double(suffix.components(separatedBy: "秒")[0]) else {
            XCTFail("計測値が見つからない: \(name)")
            return -1
        }
        return value
    }
}
