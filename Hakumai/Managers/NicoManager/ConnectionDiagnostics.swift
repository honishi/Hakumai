import Foundation
import Alamofire
import Starscream

/// 接続ごとに保持し、古い非同期処理の通知を新しい接続のログと区別する。
final class ConnectionDiagnostics {
    enum Activity: String, CaseIterable {
        case watch = "WS受信"
        case view = "NDGR View受信"
        case segment = "NDGR Segment受信"
        case comment = "コメント受信"
    }

    let id: String
    private let lock = NSLock()
    private let clock: () -> TimeInterval
    private let startedAt: TimeInterval
    private let output: (String) -> Void
    private var lastActivity: [Activity: TimeInterval] = [:]
    private var requestCount = 0

    init(id: String = String(UUID().uuidString.prefix(8)),
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         output: @escaping (String) -> Void) {
        self.id = id
        self.clock = clock
        self.startedAt = clock()
        self.output = output
    }

    @discardableResult
    func record(_ activity: Activity) -> Bool {
        lock.lock()
        let isFirst = lastActivity[activity] == nil
        lastActivity[activity] = clock()
        lock.unlock()
        return isFirst
    }

    func nextRequestID() -> Int {
        lock.lock()
        defer { lock.unlock() }
        requestCount += 1
        return requestCount
    }

    func emit(_ message: String) {
        lock.lock()
        let now = clock()
        let elapsed = Self.seconds(now - startedAt)
        let ages = Activity.allCases.map { activity in
            let age = lastActivity[activity].map { Self.seconds(now - $0) + "秒前" } ?? "未受信"
            return "\(activity.rawValue)=\(age)"
        }.joined(separator: ", ")
        lock.unlock()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        output("[接続 \(id)] \(timestamp) +\(elapsed)秒 \(message) | \(ages)")
    }

    private static func seconds(_ interval: TimeInterval) -> String {
        String(format: "%.1f", max(0, interval))
    }

    func reportStreamCompletion(_ completion: DataStreamRequest.Completion,
                                request: String, receivedBytes: Int, unreadBytes: Int) {
        // 正常なSegment完了は頻繁に起きるため、異常時だけ詳細を表示する。
        guard completion.error != nil || unreadBytes > 0 else { return }
        let status = completion.response.map { String($0.statusCode) } ?? "なし"
        emit("\(request): 完了 status=\(status), error=\(Self.errorSummary(completion.error)), 受信=\(receivedBytes)bytes, 未解析=\(unreadBytes)bytes")
    }

    /// localizedDescription / userInfo / URLには認証情報が入るため、分類と数値だけを出す。
    static func errorSummary(_ error: Error?) -> String {
        guard let error = error else { return "なし" }
        if let cause = (error as? NicoError)?.underlyingError {
            return errorSummary(cause)
        }
        if let error = error as? AFError { return alamofireErrorSummary(error) }
        if let error = error as? NdgrStreamError { return error.diagnosticSummary }
        if let error = error as? NdgrRequestThrottle.Failure { return error.diagnosticSummary }
        if let error = error as? WSError {
            return "WebSocketエラー(type=\(error.type), code=\(error.code))"
        }
        let nsError = error as NSError
        let knownDomains = [NSURLErrorDomain, NSPOSIXErrorDomain, NSCocoaErrorDomain,
                            "kCFErrorDomainCFNetwork", "kCFStreamErrorDomainSSL"]
        let domain = knownDomains.contains(nsError.domain) ? nsError.domain : "その他"
        return "\(domain)(code=\(nsError.code))"
    }

    private static func alamofireErrorSummary(_ error: AFError) -> String {
        switch error {
        case .sessionTaskFailed(let underlyingError):
            return "通信失敗(\(errorSummary(underlyingError)))"
        case .requestRetryFailed(let retryError, _):
            return errorSummary(retryError)
        case .requestAdaptationFailed(let underlyingError):
            return errorSummary(underlyingError)
        case .responseValidationFailed(let reason):
            if case .unacceptableStatusCode(let code) = reason {
                return "HTTP \(code)"
            }
            return "HTTP応答検証失敗"
        case .explicitlyCancelled:
            return "キャンセル"
        default:
            return "Alamofireエラー(code=\((error as NSError).code))"
        }
    }

    /// サーバーの任意テキストを転記せず、既知の理由コードだけを表示する。
    static func serverReason(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else { return "なし" }
        let knownReasons: Set<String> = [
            "END_PROGRAM", "SERVICE_TEMPORARILY_UNAVAILABLE", "TOO_MANY_CONNECTIONS",
            "TEMPORARILY_CROWDED", "CROWDED", "TAKEOVER", "NO_PERMISSION", "KICKED",
            "PING_TIMEOUT", "INTERNAL_SERVERERROR", "INVALID_MESSAGE", "TOO_MANY_WATCHINGS",
            "CONNECT_ERROR", "CONTENT_NOT_READY", "NO_ROOM_AVAILABLE"
        ]
        return knownReasons.contains(value) ? value : "未知の理由（本文省略）"
    }
}

/// 再取得しても改善しない認証・権限エラーや手動キャンセルは再試行しない。
enum NicoRecoveryPolicy {
    static func shouldRetry(_ error: Error) -> Bool {
        if case NdgrStreamError.truncatedFrame = error { return true }
        if let cause = (error as? NicoError)?.underlyingError {
            return shouldRetry(cause)
        }
        if let error = error as? AFError {
            switch error {
            case .sessionTaskFailed(let cause): return shouldRetry(cause)
            case .responseValidationFailed(let reason):
                if case .unacceptableStatusCode(let status) = reason {
                    return status == 429 || (500..<600).contains(status)
                }
                return false
            default: return false
            }
        }
        let error = error as NSError
        return error.domain == NSURLErrorDomain && [
            NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed
        ].contains(error.code)
    }
}
