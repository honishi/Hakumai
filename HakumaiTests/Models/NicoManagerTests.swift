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

    func testSegmentFailureInterruptsOpenViewAndResumesFromUnfinishedPosition() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            if count == 1 { return .holding(try RecoveryFixture.playlist(segment: "failed", next: 100)) }
            return .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { path in
            if path == "/failed" { return .http(503) }
            return .ok(try RecoveryFixture.comment(id: "recovered", text: "recovered") + RecoveryFixture.end())
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "ViewのEOFを待たず復旧")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 2)
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, fixture.beginAt])
        XCTAssertEqual(recorder.comments, ["recovered"])
        XCTAssertTrue(recorder.logs.contains { $0.contains("Segment失敗 → View待機を解除") })
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

    func testProgramEndDrainsEarlierHistorySegmentBeforeStopping() {
        let fixture = RecoveryFixture()
        fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
        fixture.status = { _ in "ENDED" }
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "history") + RecoveryFixture.playlist(segment: "end", next: 100))
        }
        fixture.segment = { path in
            if path == "/end" { return .delayed(try RecoveryFixture.end(), 0.02) }
            return .delayed(try RecoveryFixture.comment(id: "history", text: "last history"), 0.1)
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "並行取得中の履歴を受信して終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["last history"])
        XCTAssertEqual(fixture.viewPositions.count, 1)
        XCTAssertEqual(recorder.disconnections.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了待ち完了") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") || $0.contains("終了待ち上限") })
    }

    func testProgramEndDrainHasDeadlineAndDoesNotRecoverStalledSegment() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "stalled") + RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { path in
            if path == "/end" { return .ok(try RecoveryFixture.end()) }
            return .holding(Data())
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "終了待ち上限で停止")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, endDrainTimeout: 0.05)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 2)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertEqual(recorder.disconnections.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了待ち上限") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
    }

    func testFailureDuringEndDrainReportsCountsAndPreservesOtherSegments() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "failed") + RecoveryFixture.playlist(segment: "slow") + RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { path in
            switch path {
            case "/end": return .ok(try RecoveryFixture.end())
            case "/failed": return .delayedFailure(.cannotConnectToHost, 0.1)
            default: return .delayed(try RecoveryFixture.comment(id: "one", text: "last comment"), 0.2)
            }
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "通信失敗があっても他のSegmentを取得して終了")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["last comment"])
        XCTAssertEqual(recorder.disconnections.count, 1)
        XCTAssertEqual(fixture.programRequests, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("未完了Segment(当該含む)=2") && $0.contains("取得失敗累計=1") })
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了待ち完了: 取得失敗Segment=1") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") || $0.contains("NDGR終了待ち上限") })
    }

    func testProgramEndAtConcurrencyLimitDoesNotStartQueuedSegments() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            var entries = Data()
            for index in 1...9 { entries += try RecoveryFixture.playlist(segment: "segment\(index)") }
            return .holding(entries)
        }
        var requested: [String] = []
        fixture.segment = { path in
            requested.append(path)
            if path == "/segment8" { return .delayed(try RecoveryFixture.end(), 0.05) }
            return .holding(try RecoveryFixture.comment(id: path, text: path))
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "並行取得上限で終了通知を受け、9本目を開始しない")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder, endDrainTimeout: 0.05)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(requested.count, 8)
        XCTAssertFalse(requested.contains("/segment9"))
        XCTAssertEqual(recorder.comments.count, 7)
        XCTAssertEqual(recorder.disconnections.count, 1)
        XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR終了待ち開始: 残りSegment=7") })
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
    }

    func testManualStopCancelsProgramEndDrainAndDeadline() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in
            .holding(try RecoveryFixture.playlist(segment: "stalled") + RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { path in
            if path == "/end" { return .ok(try RecoveryFixture.end()) }
            return .holding(Data())
        }
        let recorder = RecoveryRecorder()
        let stopped = expectation(description: "終了待ち中に手動停止")
        let noDeadline = expectation(description: "停止後に期限処理しない")
        noDeadline.isInverted = true
        let manager = fixture.manager(recorder: recorder, endDrainTimeout: 0.1)
        recorder.onLog = { message in
            if message.contains("NDGR終了待ち開始") {
                DispatchQueue.main.async { manager.disconnect(); stopped.fulfill() }
            }
            if message.contains("NDGR終了待ち上限") { noDeadline.fulfill() }
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [stopped], timeout: 2)
        wait(for: [noDeadline], timeout: 0.2)
        XCTAssertEqual(recorder.disconnections.count, 1)
        XCTAssertEqual(fixture.programRequests, 1)
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
        XCTAssertEqual(recorder.recoveryNotices, 1)
        XCTAssertEqual(recorder.logs.filter { $0.contains("復旧開始") }.count, 2)
        XCTAssertFalse(recorder.disconnections.contains { if case .normal = $0 { return true }; return false })
    }

    func testSeparateInterruptionsEachAnnounceRecoveryOnce() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in .ok(try RecoveryFixture.playlist(segment: "segment\(count)")) }
        fixture.segment = { path in
            var data = try RecoveryFixture.comment(id: path, text: path)
            if path == "/segment3" { data += try RecoveryFixture.end() }
            return .ok(data)
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "復旧成功後の中断も案内する")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.recoveryNotices, 2)
        XCTAssertEqual(recorder.logs.filter { $0.contains("復旧成功") }.count, 2)
        XCTAssertEqual(recorder.comments.count, 3)
    }

    func testSuccessfulRecoveryDoesNotResetSessionLimitButManualConnectDoes() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "comment")) }
        fixture.segment = { _ in .ok(try RecoveryFixture.comment(id: "one", text: "one")) }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "実データが届いてもセッション累計の上限で停止")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder, delays: [0, 0])
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 3)
        XCTAssertEqual(recorder.logs.filter { $0.contains("復旧成功") }.count, 2)
        XCTAssertEqual(recorder.comments, ["one"])
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧断念: セッション累計の再接続上限2回") })

        let ended = expectation(description: "手動接続で復旧枠をリセット")
        fixture.view = { count, _ in
            if count == 4 { return .ok(Data()) }
            return .ok(try RecoveryFixture.playlist(segment: "end"))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.end()) }
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 5)
        XCTAssertEqual(recorder.logs.filter { $0.contains("復旧断念") }.count, 1)
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

    func testPreparationFailureReportsOnlyPreparationError() {
        let fixture = RecoveryFixture()
        fixture.programFailure = { _ in 403 }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "準備失敗を通知")
        recorder.onPreparationFailure = { failed.fulfill() }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(recorder.disconnections.count, 1)
        XCTAssertTrue(recorder.disconnections.contains { if case .preparationFailure = $0 { return true }; return false })
        XCTAssertEqual(recorder.preparationFailures, 1)
        manager.disconnect()
        XCTAssertEqual(recorder.disconnections.count, 1, "失敗後に接続状態が残らない")
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

    func testHistoryIsPublishedOnceAfterCatchUpBeforeRealtimeComments() {
        let fixture = RecoveryFixture()
        fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
        let recorder = RecoveryRecorder()
        let now = Int64(Date().timeIntervalSince1970)
        fixture.view = { count, _ in
            if count == 2 {
                XCTAssertTrue(recorder.comments.isEmpty, "最初の履歴バッチを表示せず保持する")
                XCTAssertEqual(recorder.historyBatchCount, 0)
            }
            if count == 3 {
                XCTAssertEqual(recorder.comments, ["/history1", "/history2"], "ライブ取得前に履歴をまとめて表示する")
                return .ok(try RecoveryFixture.playlist(segment: "live"))
            }
            return .ok(try RecoveryFixture.playlist(segment: "history\(count)", next: count == 1 ? 100 : now))
        }
        fixture.segment = { path in
            let data = try RecoveryFixture.comment(id: path, text: path)
            return .ok(try path == "/live" ? data + RecoveryFixture.end() : data)
        }
        let ended = expectation(description: "履歴を一括表示してからライブコメントを表示")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["/history1", "/history2", "/live"])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        XCTAssertEqual(recorder.historySummaries, [2])
    }

    func testHistorySummarySurvivesNDGRFailureAndMissingNext() {
        for truncated in [true, false] {
            let fixture = RecoveryFixture()
            fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
            fixture.view = { count, _ in
                .ok(try RecoveryFixture.playlist(segment: count == 1 ? "first" : "recovered"))
            }
            fixture.segment = { path in
                let first = try RecoveryFixture.comment(id: "one", text: "first")
                if path == "/first" { return .ok(first + (truncated ? Data([0x80]) : Data())) }
                return .ok(try first + RecoveryFixture.comment(id: "two", text: "second") + RecoveryFixture.end())
            }
            let recorder = RecoveryRecorder()
            let ended = expectation(description: "NDGR復旧をまたいで履歴件数をまとめる")
            recorder.onLog = { message in
                if message.contains("復旧開始") {
                    XCTAssertTrue(recorder.comments.isEmpty, "復旧中は取得済み履歴を表示しない")
                    XCTAssertTrue(recorder.historySummaries.isEmpty)
                }
            }
            recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
            let manager = fixture.manager(recorder: recorder)
            manager.connect(liveProgramId: "lv1")
            wait(for: [ended], timeout: 5)
            XCTAssertEqual(recorder.comments, ["first", "second"])
            XCTAssertEqual(recorder.historySummaries, [2])
            XCTAssertEqual(recorder.historyBatchCount, 1)
            XCTAssertEqual(fixture.programRequests, 2)
        }
    }

    func testUnreportedHistoryIsSummarizedWhenRecoveryFinallyFails() {
        let fixture = RecoveryFixture()
        fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
        fixture.view = { _, _ in .ok(try RecoveryFixture.playlist(segment: "history")) }
        fixture.segment = { _ in .ok(try RecoveryFixture.comment(id: "one", text: "first")) }
        fixture.programFailure = { $0 == 2 ? 403 : nil }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "最終停止時に未報告件数を通知")
        recorder.onPreparationFailure = { failed.fulfill() }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(recorder.comments, ["first"])
        XCTAssertEqual(recorder.historySummaries, [1])
    }

    func testManualStopPublishesCompletedHistoryBatchesOnce() {
        let fixture = RecoveryFixture()
        fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
        let recorder = RecoveryRecorder()
        var stop: () -> Void = {}
        fixture.view = { count, _ in
            if count == 2 {
                DispatchQueue.main.async { stop() }
                return .holding(Data())
            }
            return .ok(try RecoveryFixture.playlist(segment: "history", next: 100))
        }
        fixture.segment = { _ in .ok(try RecoveryFixture.comment(id: "one", text: "history")) }
        let stopped = expectation(description: "停止時は取得済み履歴を一度だけ表示")
        recorder.onDisconnect = { if case .normal = $0 { stopped.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        stop = {
            XCTAssertTrue(recorder.comments.isEmpty)
            manager.disconnect()
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [stopped], timeout: 5)
        XCTAssertEqual(recorder.comments, ["history"])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        XCTAssertEqual(recorder.historySummaries, [1])
        XCTAssertFalse(recorder.logs.contains { $0.contains("復旧開始") })
    }

    func testNewConnectionDoesNotReportOldHistoryCountAfterClearingTable() {
        let fixture = RecoveryFixture()
        fixture.beginAt = String(Int(Date().timeIntervalSince1970) - 10_000)
        let recorder = RecoveryRecorder()
        var switchProgram: () -> Void = {}
        fixture.view = { count, _ in
            if count == 2 {
                DispatchQueue.main.async { switchProgram() }
                return .holding(Data())
            }
            return .ok(try RecoveryFixture.playlist(segment: count == 1 ? "old" : "new", next: count == 1 ? 100 : nil))
        }
        fixture.segment = { path in
            var data = try RecoveryFixture.comment(id: path, text: path)
            if path == "/new" { data += try RecoveryFixture.end() }
            return .ok(data)
        }
        let ended = expectation(description: "新番組の件数だけを通知")
        recorder.onDisconnect = { context in
            if case .normal = context, fixture.programRequests == 2 { ended.fulfill() }
        }
        let manager = fixture.manager(recorder: recorder)
        switchProgram = {
            XCTAssertTrue(recorder.comments.isEmpty, "切替前の履歴はまだ表示しない")
            XCTAssertTrue(recorder.historySummaries.isEmpty)
            // connectLive と同じく、新しい接続を要求する前にテーブルを消す。
            recorder.comments.removeAll()
            manager.connect(liveProgramId: "lv2")
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["/new"])
        XCTAssertEqual(recorder.historySummaries, [1])
        XCTAssertTrue(recorder.logs.contains { $0.contains("旧接続の未表示履歴1件") })
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
        requestRecovery = {
            XCTAssertTrue(recorder.comments.isEmpty, "再接続前の履歴は保持だけ行う")
            manager.reconnect(reason: .normal)
        }
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["history"])
        XCTAssertEqual(recorder.historySummaries, [1])
        XCTAssertEqual(recorder.historyBatchCount, 1)
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, "100", "100"])
        XCTAssertTrue(recorder.logs.contains { $0.contains("旧コメントWSの空送信・Ping監視タイマーは起動しない") })
    }

    func testTruncatedSegmentRecoversWithoutDuplicatingCompletedFrames() {
        let fixture = RecoveryFixture()
        fixture.view = { count, _ in
            .ok(try RecoveryFixture.playlist(segment: count == 1 ? "partial" : "recovered", next: 100))
        }
        fixture.segment = { path in
            let first = try RecoveryFixture.comment(id: "one", text: "first")
            if path == "/partial" { return .ok(first + Data([0x80])) }
            return .ok(try first + RecoveryFixture.comment(id: "two", text: "second") + RecoveryFixture.end())
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "未完フレームから復旧")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, ["first", "second"])
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, fixture.beginAt])
        XCTAssertTrue(recorder.logs.contains { $0.contains("復旧開始") && $0.contains("NDGRフレーム途中で受信終了") })
    }

    func testSplitFramesRecoverFromTruncatedEOFWithoutDuplicatingComments() throws {
        let fixture = RecoveryFixture()
        let text = String(repeating: "長いコメント", count: 40)
        let first = try RecoveryFixture.comment(id: "one", text: text)
        let second = try RecoveryFixture.comment(id: "two", text: "second")
        fixture.view = { count, _ in
            .ok(try RecoveryFixture.playlist(segment: count == 1 ? "partial" : "recovered", next: 100))
        }
        fixture.segment = { path in
            // 長さのvarint自体と本文をそれぞれ分割し、最後だけ次のフレームを途中で切る。
            var chunks = [Data(first.prefix(1)), Data(first.dropFirst().prefix(3)), Data(first.dropFirst(4))]
            if path == "/partial" {
                chunks.append(Data(second.prefix(3)))
            } else {
                chunks += [Data(second.prefix(2)), Data(second.dropFirst(2)), try RecoveryFixture.end()]
            }
            return .chunks(chunks, 0.02)
        }
        let recorder = RecoveryRecorder()
        let ended = expectation(description: "分割フレームを復元し、未完EOFのみ再取得する")
        recorder.onDisconnect = { if case .normal = $0 { ended.fulfill() } }
        let manager = fixture.manager(recorder: recorder)
        manager.connect(liveProgramId: "lv1")
        wait(for: [ended], timeout: 5)
        XCTAssertEqual(recorder.comments, [text, "second"])
        XCTAssertEqual(fixture.viewPositions, [fixture.beginAt, fixture.beginAt])
        XCTAssertEqual(recorder.logs.filter { $0.contains("復旧開始") }.count, 1)
    }

    func testRepeatedTruncatedViewsStopAtRecoveryLimit() {
        let fixture = RecoveryFixture()
        fixture.view = { _, _ in .ok(Data([0x80])) }
        let recorder = RecoveryRecorder()
        let failed = expectation(description: "繰り返す不完全データは上限で停止")
        recorder.onDisconnect = { if case .failure = $0 { failed.fulfill() } }
        let manager = fixture.manager(recorder: recorder, delays: [0, 0])
        manager.connect(liveProgramId: "lv1")
        wait(for: [failed], timeout: 5)
        XCTAssertEqual(fixture.programRequests, 3)
        XCTAssertEqual(fixture.viewPositions.count, 3)
        XCTAssertFalse(recorder.disconnections.contains { if case .normal = $0 { return true }; return false })
    }

    func testRecoveryPolicyRetriesTransientFailuresOnly() {
        XCTAssertTrue(NicoRecoveryPolicy.shouldRetry(NdgrStreamError.truncatedFrame))
        XCTAssertFalse(NicoRecoveryPolicy.shouldRetry(NdgrStreamError.invalidSegmentURL))
        XCTAssertFalse(NicoRecoveryPolicy.shouldRetry(NdgrStreamError.programEnded))
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
