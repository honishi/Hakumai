import Foundation
import XCTest
import Alamofire
@testable import Hakumai

final class NdgrTransportTests: XCTestCase {
    @MainActor
    func testRenewalKeepsParallelReaderAndUsesNewSessionForFollowingRequests() async {
        let transport = NdgrTransport(configuration: .ephemeral, throttle: NdgrRequestThrottle(report: { _ in }))
        defer { transport.cancelAllRequests() }
        var sessions: [Session] = []
        var slowContinuation: AsyncThrowingStream<Int, Error>.Continuation?
        let started = expectation(description: "並行読み取り開始")
        let completed = expectation(description: "並行読み取り完了")
        let slow = transport.stream(report: { _ in }, installStop: { _ in }, makeStream: { session, _, _ in
            sessions.append(session)
            return AsyncThrowingStream<Int, Error> { continuation in
                slowContinuation = continuation
                started.fulfill()
            }
        })
        let reader = Task { @MainActor in
            var values: [Int] = []
            do {
                for try await value in slow { values.append(value) }
                XCTAssertEqual(values, [9])
            } catch { XCTFail("並行読み取りが中止された") }
            completed.fulfill()
        }
        defer { reader.cancel() }
        await fulfillment(of: [started], timeout: 2)
        var attempts = 0
        var values: [Int] = []
        let retrying = transport.stream(report: { _ in }, installStop: { _ in }, makeStream: { session, _, _ in
            sessions.append(session)
            attempts += 1
            return AsyncThrowingStream<Int, Error> { continuation in
                if attempts == 1 {
                    continuation.finish(throwing: NdgrRequestRetrier.ConnectionRenewal(delay: 0))
                } else {
                    continuation.yield(2)
                    continuation.finish()
                }
            }
        })
        do { for try await value in retrying { values.append(value) } } catch { XCTFail("再試行失敗: \(error)") }
        XCTAssertEqual(values, [2])
        if sessions.count == 3 {
            XCTAssertTrue(sessions[0] === sessions[1])
            XCTAssertFalse(sessions[1].session === sessions[2].session)
        }
        slowContinuation?.yield(9)
        slowContinuation?.finish()
        await fulfillment(of: [completed], timeout: 2)
        await assertFollowingUsesCurrentSession(transport, expected: sessions.last)
    }

    @MainActor
    private func assertFollowingUsesCurrentSession(_ transport: NdgrTransport, expected: Session?) async {
        let following = transport.stream(report: { _ in }, installStop: { _ in }, makeStream: { session, generation, _ in
            XCTAssertEqual(generation, 2)
            XCTAssertTrue(session === expected)
            return AsyncThrowingStream<Int, Error> { $0.finish() }
        })
        do { for try await _ in following {} } catch { XCTFail("後続取得失敗") }
    }

    @MainActor
    func testConcurrentTimeoutsShareTheRenewedSession() async {
        let transport = NdgrTransport(configuration: .ephemeral, throttle: NdgrRequestThrottle(report: { _ in }))
        defer { transport.cancelAllRequests() }
        var pending: [AsyncThrowingStream<Int, Error>.Continuation] = []
        var sessions: [Session] = []
        var logs: [String] = []
        let started = expectation(description: "同じ世代で2件の取得開始")
        started.expectedFulfillmentCount = 2
        let completed = expectation(description: "2件とも更新後に完了")
        completed.expectedFulfillmentCount = 2
        for _ in 0..<2 {
            let stream = transport.stream(report: { logs.append($0) }, installStop: { _ in }, makeStream: { session, generation, _ in
                sessions.append(session)
                return AsyncThrowingStream<Int, Error> { continuation in
                    if generation == 1 {
                        pending.append(continuation)
                        started.fulfill()
                    } else {
                        XCTAssertEqual(generation, 2)
                        continuation.finish()
                    }
                }
            })
            Task { @MainActor in
                do { for try await _ in stream {} } catch { XCTFail("再試行失敗") }
                completed.fulfill()
            }
        }
        await fulfillment(of: [started], timeout: 2)
        for continuation in pending { continuation.finish(throwing: NdgrRequestRetrier.ConnectionRenewal(delay: 0)) }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(sessions.count, 4)
        if sessions.count == 4 { XCTAssertTrue(sessions[2] === sessions[3]) }
        XCTAssertEqual(logs.filter { $0.contains("通信接続を更新:") }.count, 1)
        XCTAssertEqual(logs.filter { $0.contains("通信接続は更新済み:") }.count, 1)
    }

    @MainActor
    func testSessionExpiresFiveMinutesAfterCreationDespiteContinuedRequests() async throws {
        var now: TimeInterval = 0
        let transport = NdgrTransport(configuration: .ephemeral, throttle: NdgrRequestThrottle(report: { _ in }),
                                      clock: { now })
        defer { transport.cancelAllRequests() }
        var sessions: [Session] = []
        var generations: [Int] = []
        var metrics: [Bool] = []
        var logs: [String] = []
        for time in [0.0, 299, 300, 301, 599, 600] {
            now = time
            try await readOnce(transport, report: { logs.append($0) }, inspect: { session, generation, reportMetrics in
                sessions.append(session)
                generations.append(generation)
                metrics.append(reportMetrics)
            })
        }
        XCTAssertEqual(generations, [1, 1, 2, 2, 2, 3])
        XCTAssertEqual(metrics, [false, false, true, false, false, true])
        XCTAssertEqual(sessions.count, 6)
        if sessions.count == 6 {
            XCTAssertTrue(sessions[0] === sessions[1])
            XCTAssertFalse(sessions[1].session === sessions[2].session)
            XCTAssertTrue(sessions[2] === sessions[4])
            XCTAssertFalse(sessions[4].session === sessions[5].session)
        }
        XCTAssertEqual(logs.filter { $0.contains("通信接続を予防更新:") }.count, 2)
        XCTAssertTrue(logs.allSatisfy { $0.contains("経過=300.000秒, 上限=300.0秒") })
    }

    @MainActor
    func testPreventiveRenewalKeepsOldReadersAndTheirTimeoutUsesCurrentSession() async throws {
        var now: TimeInterval = 0
        let transport = NdgrTransport(configuration: .ephemeral, throttle: NdgrRequestThrottle(report: { _ in }),
                                      clock: { now })
        defer { transport.cancelAllRequests() }
        var pending: [AsyncThrowingStream<Int, Error>.Continuation] = []
        var logs: [String] = []
        var newSession: Session?
        var values: [Int] = []
        let started = expectation(description: "旧世代の2件を開始")
        started.expectedFulfillmentCount = 2
        let completed = expectation(description: "旧世代の受信と再試行を完了")
        completed.expectedFulfillmentCount = 2
        for _ in 0..<2 {
            let stream = transport.stream(report: { logs.append($0) }, installStop: { _ in },
                                          makeStream: { session, generation, reportMetrics in
                                            AsyncThrowingStream<Int, Error> { continuation in
                                                if generation == 1 {
                                                    pending.append(continuation)
                                                    started.fulfill()
                                                } else {
                                                    XCTAssertTrue(session === newSession)
                                                    XCTAssertFalse(reportMetrics)
                                                    continuation.yield(2)
                                                    continuation.finish()
                                                }
                                            }
                                          })
            Task { @MainActor in
                do { for try await value in stream { values.append(value) } } catch { XCTFail("旧世代の受信失敗: \(error)") }
                completed.fulfill()
            }
        }
        await fulfillment(of: [started], timeout: 2)
        now = 300
        try await readOnce(transport, report: { logs.append($0) }, inspect: { session, generation, reportMetrics in
            newSession = session
            XCTAssertEqual(generation, 2)
            XCTAssertTrue(reportMetrics)
        })
        XCTAssertTrue(logs.contains { $0.contains("並行受信=2件は継続") })
        if pending.count == 2 {
            pending[0].yield(9)
            pending[0].finish()
            pending[1].finish(throwing: NdgrRequestRetrier.ConnectionRenewal(delay: 0))
        }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(values.sorted(), [2, 9])
        XCTAssertEqual(logs.filter { $0.contains("通信接続を予防更新:") }.count, 1)
        XCTAssertEqual(logs.filter { $0.contains("通信接続は更新済み:") }.count, 1)
        XCTAssertFalse(logs.contains { $0.contains("通信接続を更新:") })
    }

    @MainActor
    func testStoppedTransportDoesNotRenewAnExpiredSession() async {
        for cancelAll in [false, true] {
            var now: TimeInterval = 0
            let transport = NdgrTransport(configuration: .ephemeral, throttle: NdgrRequestThrottle(report: { _ in }),
                                          clock: { now })
            defer { transport.cancelAllRequests() }
            if cancelAll { transport.cancelAllRequests() } else { transport.stopNewRequests() }
            now = 301
            do {
                try await readOnce(transport, report: { _ in XCTFail("停止後に接続を更新した") }, inspect: { _, _, _ in
                    XCTFail("停止後に取得を開始した")
                })
                XCTFail("停止が伝播しなかった")
            } catch is CancellationError {
                // 放送終了・手動停止を予防更新で再開しない。
            } catch { XCTFail("予期しない失敗: \(error)") }
        }
    }

    @MainActor
    private func readOnce(_ transport: NdgrTransport, report: @escaping (String) -> Void,
                          inspect: @escaping (Session, Int, Bool) -> Void) async throws {
        let stream = transport.stream(report: report, installStop: { _ in }, makeStream: { session, generation, reportMetrics in
            inspect(session, generation, reportMetrics)
            return AsyncThrowingStream<Int, Error> { $0.finish() }
        })
        for try await _ in stream {}
    }
}
