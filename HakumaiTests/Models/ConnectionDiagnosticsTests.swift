import Foundation
import XCTest
import Alamofire
import Starscream
@testable import Hakumai

final class ConnectionDiagnosticsTests: XCTestCase {
    func testActivityAgesAndConnectionIDsDoNotRequirePerMessageLogging() {
        var now: TimeInterval = 100
        var messages: [String] = []
        let old = ConnectionDiagnostics(id: "old", clock: { now }, output: { messages.append($0) })
        old.record(.watch)
        now = 110
        old.record(.comment)
        XCTAssertTrue(messages.isEmpty)

        let new = ConnectionDiagnostics(id: "new", clock: { now }, output: { messages.append($0) })
        now = 190
        old.emit("古い接続の終了通知")
        new.emit("新しい接続")

        XCTAssertTrue(messages[0].contains("[接続 old]"))
        XCTAssertTrue(messages[0].contains("+90.0秒"))
        XCTAssertTrue(messages[0].contains("WS受信=90.0秒前"))
        XCTAssertTrue(messages[0].contains("コメント受信=80.0秒前"))
        XCTAssertTrue(messages[1].contains("[接続 new]"))
        XCTAssertTrue(messages[1].contains("コメント受信=未受信"))
    }

    func testErrorSummariesDoNotExposeURLsDescriptionsOrSocketReasons() {
        let secret = "https://example.invalid/private-token?audienceToken=secret"
        let underlying = NSError(domain: NSURLErrorDomain, code: -1001, userInfo: [
            NSLocalizedDescriptionKey: secret,
            NSURLErrorFailingURLStringErrorKey: secret
        ])
        let errors: [Error] = [
            underlying,
            AFError.sessionTaskFailed(error: underlying),
            WSError(type: .serverError, message: secret, code: 1006),
            NSError(domain: secret, code: 99),
            NicoError.transport(AFError.sessionTaskFailed(error: underlying)),
            AFError.requestAdaptationFailed(error: underlying),
            AFError.requestRetryFailed(retryError: AFError.requestAdaptationFailed(error: underlying),
                                       originalError: NSError(domain: secret, code: 99))
        ]
        for error in errors {
            let summary = ConnectionDiagnostics.errorSummary(error)
            XCTAssertFalse(summary.contains("secret"))
            XCTAssertFalse(summary.contains("private-token"))
            XCTAssertFalse(summary.contains("https://"))
        }
        XCTAssertTrue(ConnectionDiagnostics.errorSummary(errors[1]).contains("-1001"))
        XCTAssertTrue(ConnectionDiagnostics.errorSummary(errors[2]).contains("1006"))
        XCTAssertEqual(ConnectionDiagnostics.serverReason(secret), "未知の理由（本文省略）")
        XCTAssertEqual(ConnectionDiagnostics.serverReason("END_PROGRAM"), "END_PROGRAM")
    }

    func testRateLimitStopReasonsSurviveAlamofireWrappingWithoutEnablingRecovery() {
        let reasons: [(NdgrRequestThrottle.Failure, String)] = [
            (.rateLimitExhausted, "HTTP 429: 待機再試行上限に到達"),
            (.serverWaitTooLong, "HTTP 429: サーバー指定の待機時間が上限を超過")
        ]
        let original = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 429))
        for (reason, expected) in reasons {
            let adapted = AFError.requestAdaptationFailed(error: reason)
            let errors: [Error] = [
                reason, adapted,
                AFError.requestRetryFailed(retryError: reason, originalError: original),
                NicoError.transport(AFError.requestRetryFailed(retryError: adapted, originalError: original))
            ]
            for error in errors {
                XCTAssertEqual(ConnectionDiagnostics.errorSummary(error), expected)
                XCTAssertFalse(NicoRecoveryPolicy.shouldRetry(error))
            }
        }
    }

    func testNDGRTimeoutReportsRetryThenCompletionBeforeEndNotification() throws {
        let messages = try runNDGR(path: "timeout")
        let retry = try XCTUnwrap(messages.firstIndex { $0.contains("1回目の再試行を実行") })
        let exhausted = try XCTUnwrap(messages.firstIndex { $0.contains("再試行上限に到達") })
        let completed = try XCTUnwrap(messages.firstIndex { $0.contains("完了 status=") })
        let ended = try XCTUnwrap(messages.firstIndex { $0.contains("NDGR終了通知: 通信・解析失敗") })
        XCTAssertLessThan(retry, exhausted)
        XCTAssertLessThan(exhausted, completed)
        XCTAssertLessThan(completed, ended)
        XCTAssertTrue(messages[completed].contains("-1001"))
        XCTAssertTrue(messages[retry].contains("HTTP#1"))
        XCTAssertTrue(messages[completed].contains("HTTP#1"))
    }

    func testNDGRHTTPFailureReportsStatusWithoutChangingRetryPolicy() throws {
        let messages = try runNDGR(path: "unavailable")
        XCTAssertTrue(messages.contains { $0.contains("再試行対象外: HTTP 503") })
        XCTAssertTrue(messages.contains { $0.contains("完了 status=503, error=HTTP 503") })
        XCTAssertFalse(messages.contains { $0.contains("1回目の再試行を実行") })
    }

    func testNDGRCleanEOFWithoutNextReportsLoopEndRatherThanProgramEnd() throws {
        let messages = try runNDGR(path: "empty")
        XCTAssertTrue(messages.contains { $0.contains("次の取得位置なし") })
        XCTAssertFalse(messages.contains { $0.contains("サーバーから放送終了状態を受信") })
        // 起動時の再試行上限の設定表示と、実際の再試行を区別する。
        XCTAssertFalse(messages.contains { $0.contains("再試行を実行") || $0.contains("取得を一時停止") })
    }

    private func runNDGR(path: String) throws -> [String] {
        let recorder = DiagnosticMessages()
        let diagnostics = ConnectionDiagnostics(id: "test", output: recorder.append)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DiagnosticURLProtocol.self]
        let delegate = DiagnosticNDGRDelegate(finished: expectation(description: "NDGR終了"))
        let client = NdgrClient(delegate: delegate, configuration: configuration, retryPolicy: .init(maxRetries: 1, initialDelay: 0))
        let url = try XCTUnwrap(URL(string: "https://diagnostics.invalid/\(path)?token=secret"))
        client.connect(viewUri: url, beginTime: Date(), diagnostics: diagnostics)
        wait(for: [delegate.finished], timeout: 5)
        withExtendedLifetime(client) {}
        XCTAssertEqual(delegate.endedConnectionID, "test")
        let messages = recorder.snapshot()
        XCTAssertTrue(messages.allSatisfy { $0.contains("[接続 test]") })
        XCTAssertFalse(messages.contains { $0.contains("secret") || $0.contains("diagnostics.invalid") })
        return messages
    }
}

private final class DiagnosticMessages {
    private let lock = NSLock()
    private var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return messages
    }
}

private final class DiagnosticNDGRDelegate: NdgrClientDelegate {
    let finished: XCTestExpectation
    var endedConnectionID: String?

    init(finished: XCTestExpectation) {
        self.finished = finished
    }

    func ndgrClientDidConnect(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics) {}
    func ndgrClientWillWaitForRateLimit(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics) {}
    func ndgrClientDidReceiveChat(_ ndgrClient: NdgrClientType, chat: Chat, diagnostics: ConnectionDiagnostics) {}
    func ndgrClientDidFinishChatHistory(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics) {}
    func ndgrClientReceivingChatHistory(_ ndgrClient: NdgrClientType, requestCount: Int, totalChatCount: Int, diagnostics: ConnectionDiagnostics) {}
    func ndgrClientDidReceiveChatHistory(_ ndgrClient: NdgrClientType, chats: [Chat], diagnostics: ConnectionDiagnostics) {}

    func ndgrClientDidDisconnect(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics, reason: NdgrTermination) {
        endedConnectionID = diagnostics.id
        finished.fulfill()
    }
}

private class DiagnosticURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        if url.path == "/timeout" {
            client?.urlProtocol(self, didFailWithError: NSError(domain: NSURLErrorDomain, code: -1001))
            return
        }
        let status = url.path == "/unavailable" ? 503 : 200
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
