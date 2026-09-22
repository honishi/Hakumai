import Foundation
import XCTest
@testable import Hakumai

final class NdgrStreamTimeoutTests: XCTestCase {
    func testViewHeaderTimeoutRetriesWithoutRestartingSession() throws {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            count == 1 ? .awaitingHeaders : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    policy: .init(view: .init(header: 0.05, body: 1), segment: .init(header: 1, body: 1)))
        XCTAssertEqual(fixture.viewPositions.count, 2)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.logs.filter { $0.contains("ヘッダー待ちタイムアウト") }.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("HTTP再試行で回復") })
        XCTAssertEqual(recorder.recoveryNotices, 0)
        let deadline = try XCTUnwrap(recorder.logs.firstIndex { $0.contains("ヘッダー待ち期限到達:") })
        let confirmed = try XCTUnwrap(recorder.logs.firstIndex { $0.contains("ヘッダー待ちタイムアウト:") && $0.contains("終了原因を確認") })
        let retry = try XCTUnwrap(recorder.logs.firstIndex { $0.contains("1回目の再試行を実行") })
        XCTAssertLessThan(deadline, confirmed)
        XCTAssertLessThan(confirmed, retry)
        let attempts = recorder.logs.filter { $0.contains("View受信 HTTP#1: HTTP試行計測:") }
        XCTAssertEqual(attempts.count, 2)
        XCTAssertTrue(attempts[0].contains("試行=1, 結果=通信失敗(NSURLErrorDomain(code=-1001))"))
        XCTAssertTrue(attempts[1].contains("試行=2, 結果=成功"))
    }

    func testSegmentHeaderTimeoutExhaustionRecoversSession() throws {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "end")) }
        var requests = 0
        fixture.segment = { _ in
            requests += 1
            if requests <= 2 { return .awaitingHeaders }
            return .ok(try RecoveryFixture.comment(id: "recovered", text: "復旧後") + RecoveryFixture.end())
        }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    policy: .init(view: .init(header: 1, body: 1), segment: .init(header: 0.05, body: 1)))
        XCTAssertEqual(requests, 3)
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(recorder.logs.filter { $0.contains("ヘッダー待ちタイムアウト") }.count, 2)
        XCTAssertEqual(recorder.recoveryNotices, 1)
        XCTAssertEqual(recorder.comments, ["復旧後"])
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧成功") })
    }

    func testSegmentBodyTimeoutRetriesAndDeduplicatesReceivedComments() throws {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "end")) }
        var requests = 0
        fixture.segment = { _ in
            requests += 1
            let comment = try RecoveryFixture.comment(id: "one", text: "一度だけ")
            return requests == 1 ? .holding(comment) : .ok(comment + (try RecoveryFixture.end()))
        }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    policy: .init(view: .init(header: 1, body: 1), segment: .init(header: 1, body: 0.05)))
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(recorder.comments, ["一度だけ"])
        XCTAssertEqual(recorder.logs.filter { $0.contains("本文待ちタイムアウト") }.count, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
    }

    func testBodyDeadlineStartsAtHeadersAndResetsOnEachChunk() throws {
        let fixture = RecoveryFixture()
        // ヘッダー後の本文待ちは、ヘッダーの期限を超えても許容する。
        fixture.view = { _, _ in .delayed(try RecoveryFixture.playlist(segment: "end"), 0.12) }
        fixture.segment = { _ in
            let comments = try (0..<4).map { try RecoveryFixture.comment(id: "\($0)", text: "\($0)") }
            return .chunks(comments + [try RecoveryFixture.end()], 0.08)
        }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    policy: .init(view: .init(header: 0.05, body: 0.3), segment: .init(header: 0.05, body: 0.3)))
        XCTAssertEqual(recorder.comments, ["0", "1", "2", "3"])
        XCTAssertFalse(recorder.logs.contains { $0.contains("タイムアウト:") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("1回目の再試行") })
    }

    func testViewBodySilenceTimesOutEvenWithoutComments() throws {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            count == 1 ? .holding(Data()) : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    policy: .init(view: .init(header: 1, body: 0.05), segment: .init(header: 1, body: 1)))
        XCTAssertEqual(fixture.viewPositions.count, 2)
        XCTAssertEqual(recorder.logs.filter { $0.contains("本文待ちタイムアウト") }.count, 1)
        XCTAssertEqual(recorder.recoveryNotices, 0)
    }

    func testRateLimitWaitDoesNotConsumeHeaderDeadline() throws {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            count == 1 ? .http(429) : .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let recorder = RecoveryRecorder()
        runUntilEnd(fixture, recorder: recorder,
                    policy: .init(view: .init(header: 0.05, body: 0.05), segment: .init(header: 0.05, body: 0.05)),
                    throttle: .init(interval: 0.15, retryDelays: [0.2]))
        XCTAssertEqual(fixture.viewPositions.count, 2)
        XCTAssertEqual(recorder.rateLimitWaitNotices, 1)
        XCTAssertFalse(recorder.logs.contains { $0.contains("タイムアウト:") })
        XCTAssertEqual(recorder.recoveryNotices, 0)
    }

    func testManualDisconnectCancelsBothKindsOfDeadline() throws {
        for header in [true, false] {
            let fixture = RecoveryFixture()
            let recorder = RecoveryRecorder()
            var stop: () -> Void = {}
            fixture.view = { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { stop() }
                return header ? .awaitingHeaders : .holding(Data())
            }
            let policy = NdgrStreamTimeout.Policy(view: .init(header: 0.1, body: 0.1))
            let manager = fixture.manager(recorder: recorder, timeoutPolicy: policy)
            let settled = expectation(description: "切断後の期限を通過")
            stop = {
                manager.disconnect()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
            }
            manager.connect(liveProgramId: "lv1")
            wait(for: [settled], timeout: 3)
            XCTAssertEqual(fixture.viewPositions.count, 1)
            XCTAssertFalse(recorder.logs.contains { $0.contains("タイムアウト:") })
            XCTAssertEqual(recorder.recoveryNotices, 0)
        }
    }

    func testOldDeadlineDoesNotInterruptNewConnection() throws {
        let fixture = RecoveryFixture()
        let recorder = RecoveryRecorder()
        var switchProgram: () -> Void = {}
        fixture.view = { count, _ in
            if count == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { switchProgram() }
                return .awaitingHeaders
            }
            return .delayed(try RecoveryFixture.playlist(segment: "end"), 0.25)
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        let policy = NdgrStreamTimeout.Policy(view: .init(header: 0.1, body: 1))
        let manager = fixture.manager(recorder: recorder, timeoutPolicy: policy)
        let ended = expectation(description: "新しい接続が旧期限を超えて正常終了")
        recorder.onDisconnect = {
            if case .normal = $0, fixture.programRequests == 2 { ended.fulfill() }
        }
        switchProgram = { manager.connect(liveProgramId: "lv2") }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(fixture.viewPositions.count, 2)
        XCTAssertFalse(recorder.logs.contains { $0.contains("タイムアウト:") })
        XCTAssertEqual(recorder.recoveryNotices, 0)
        recorder.onDisconnect = nil
        manager.disconnect()
    }

    private func runUntilEnd(_ fixture: RecoveryFixture, recorder: RecoveryRecorder,
                             policy: NdgrStreamTimeout.Policy,
                             throttle: NdgrRequestThrottle.Policy = .init()) {
        let ended = expectation(description: "放送終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, throttlePolicy: throttle, timeoutPolicy: policy)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        recorder.onDisconnect = nil
        manager.disconnect()
    }
}
