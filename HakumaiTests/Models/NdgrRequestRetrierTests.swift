import Foundation
import XCTest
import Starscream
@testable import Hakumai

final class NdgrRequestRetrierTests: XCTestCase {
    func testFiveSegmentBodyRetriesRecoverWithoutDuplicatingComments() throws {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "end")) }
        var attempts = 0
        fixture.segment = { _ in
            attempts += 1
            let comment = try RecoveryFixture.comment(id: "same", text: "一度だけ表示")
            return attempts <= 5 ? .holding(comment) : .ok(comment + (try RecoveryFixture.end()))
        }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    timeoutPolicy: .init(segment: .init(header: 1, body: 0.03)))
        XCTAssertEqual(attempts, 6)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.comments, ["一度だけ表示"])
        XCTAssertEqual(recorder.recoveryNotices, 0)
        XCTAssertEqual(recorder.logs.filter { $0.contains("本文待ちタイムアウト") }.count, 5)
        XCTAssertTrue(recorder.logs.contains { $0.contains("5回目の再試行を実行") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("再試行上限に到達") })
        XCTAssertEqual(recorder.logs.filter { $0.contains("通信接続を更新:") }.count, 5)
    }

    func testSixViewFailuresTriggerSessionRecovery() throws {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            count <= 6 ? .timeout : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.comment(id: "new", text: "復旧") + RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder)
        XCTAssertEqual(fixture.viewPositions.count, 7)
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(recorder.recoveryNotices, 1)
        XCTAssertEqual(recorder.logs.filter { $0.contains("再試行上限に到達") }.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧成功") })
        XCTAssertEqual(recorder.logs.filter { $0.contains("通信接続を更新:") }.count, 5)
    }

    func testRateLimitDoesNotConsumeTheFiveNetworkRetries() throws {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            if count == 3 { return .http(429) }
            return count <= 6 ? .timeout : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder)
        XCTAssertEqual(fixture.viewPositions.count, 7)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.rateLimitWaitNotices, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        XCTAssertTrue(recorder.logs.contains { $0.contains("5回目の再試行を実行") })
        XCTAssertTrue(recorder.logs.contains {
            $0.contains("HTTP再試行で回復") && $0.contains("通信再試行済み=5回, 総再試行済み（429含む）=6回")
        })
    }

    func testNonRetryableErrorDistinguishesNetworkRetriesFromRateLimits() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            if count == 1 { return .timeout }
            return count == 2 ? .http(429) : .http(403)
        }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "403で終了")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(retryDelays: [0.01]),
                                      retryPolicy: .init(initialDelay: 0))
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(fixture.viewPositions.count, 3)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        XCTAssertTrue(recorder.logs.contains {
            $0.contains("再試行対象外: HTTP 403") && $0.contains("通信再試行済み=1回, 総再試行済み（429含む）=2回")
        })
        recorder.onDisconnect = nil
        manager.disconnect()
    }

    func testDefaultFirstRetryWaitsHalfASecond() throws {
        let fixture = RecoveryFixture()
        var timestamps: [TimeInterval] = []
        fixture.view = { count, _ in
            timestamps.append(ProcessInfo.processInfo.systemUptime)
            return count == 1 ? .timeout : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder, retryPolicy: .init())
        XCTAssertEqual(timestamps.count, 2)
        if timestamps.count == 2 { XCTAssertGreaterThanOrEqual(timestamps[1] - timestamps[0], 0.45) }
        XCTAssertTrue(recorder.logs.contains { $0.contains("上限=5回, 待機=0.500秒") })
    }

    func testManualStopAndWatchEndCancelPendingNetworkRetry() {
        for manual in [true, false] {
            let fixture = RecoveryFixture()
            fixture.view = { _, _ in .timeout }
            let recorder = RecoveryRecorder()
            let manager = fixture.manager(recorder: recorder, retryPolicy: .init())
            let settled = expectation(description: "再試行の待機期限後も停止")
            recorder.onLog = { message in
                guard message.contains("通信接続を更新:") else { return }
                recorder.onLog = nil
                DispatchQueue.main.async {
                    if manual {
                        manager.disconnect()
                    } else {
                        fixture.engines.last?.delegate?.didReceive(event: .text("{\"type\":\"disconnect\",\"data\":{\"reason\":\"END_PROGRAM\"}}"))
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { settled.fulfill() }
                }
            }
            manager.connect(liveProgramId: "lv1")
            wait(for: [settled], timeout: 3)
            XCTAssertEqual(fixture.viewPositions.count, 1)
            XCTAssertEqual(fixture.programRequests, 1)
            XCTAssertEqual(recorder.recoveryNotices, 0)
            XCTAssertTrue(recorder.disconnections.contains { if case .normal = $0 { return true }; return false })
            manager.disconnect()
        }
    }

    func testRateLimitBudgetSurvivesConnectionRenewal() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in count % 2 == 1 ? .timeout : .http(429) }
        let recorder = RecoveryRecorder()
        let stopped = expectation(description: "接続更新をまたいでも429上限で停止")
        recorder.onDisconnect = { if case .failure = $0 { stopped.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(retryDelays: [0.01]),
                                      retryPolicy: .init(initialDelay: 0))
        manager.connect(liveProgramId: "lv1")
        wait(for: [stopped], timeout: 5)
        XCTAssertEqual(fixture.viewPositions.count, 4)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.rateLimitWaitNotices, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        XCTAssertEqual(recorder.logs.filter { $0.contains("通信接続を更新:") }.count, 2)
        recorder.onDisconnect = nil
        manager.disconnect()
    }

    func testConnectionRenewalDiscardsPartialProtobufFrame() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "end")) }
        var attempts = 0
        fixture.segment = { _ in
            attempts += 1
            let comment = try RecoveryFixture.comment(id: "one", text: "分割フレーム")
            return attempts == 1 ? .holding(Data(comment.prefix(2))) : .ok(comment + (try RecoveryFixture.end()))
        }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder, timeoutPolicy: .init(segment: .init(header: 1, body: 0.05)))
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(recorder.comments, ["分割フレーム"])
        XCTAssertEqual(recorder.recoveryNotices, 0)
    }

    func testNDGREndCancelsSegmentRetryAfterConnectionRenewal() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "stalled") + RecoveryFixture.playlist(segment: "end"))
        }
        var attempts = 0
        fixture.segment = { path in
            if path == "/end" { return .delayed(try RecoveryFixture.end(), 0.1) }
            attempts += 1
            return .timeout
        }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder, retryPolicy: .init())
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
        XCTAssertTrue(recorder.logs.contains { $0.contains("通信接続を更新:") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("NDGR終了待ち上限:") })
    }

    func testTimeoutConnectionRenewalCanBeDisabledForComparison() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in count == 1 ? .timeout : .ok(try RecoveryFixture.playlist(segment: "end")) }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder, retryPolicy: .init(initialDelay: 0, renewConnectionOnTimeout: false))
        XCTAssertEqual(fixture.viewPositions.count, 2)
        XCTAssertFalse(recorder.logs.contains { $0.contains("通信接続を更新:") })
        XCTAssertTrue(recorder.logs.contains { $0.contains("HTTP再試行で回復") })
    }

    private func runUntilEnd(_ fixture: RecoveryFixture, recorder: RecoveryRecorder,
                             retryPolicy: NdgrRequestRetrier.Policy = .init(initialDelay: 0),
                             timeoutPolicy: NdgrStreamTimeout.Policy = .init()) {
        let ended = expectation(description: "放送終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: .init(retryDelays: [0.01]),
                                      timeoutPolicy: timeoutPolicy, retryPolicy: retryPolicy)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        recorder.onDisconnect = nil
        manager.disconnect()
    }
}
