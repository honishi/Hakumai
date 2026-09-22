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
        let slow = transport.stream(report: { _ in }, installStop: { _ in }, makeStream: { session, _ in
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
        let retrying = transport.stream(report: { _ in }, installStop: { _ in }, makeStream: { session, _ in
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
        let following = transport.stream(report: { _ in }, installStop: { _ in }, makeStream: { session, generation in
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
            let stream = transport.stream(report: { logs.append($0) }, installStop: { _ in }, makeStream: { session, generation in
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
}
