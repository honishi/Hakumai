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
    // ISO8601DateFormatter は内部で排他しないため、接続ごとに持ち lock 内でのみ使う。
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let clock: () -> TimeInterval
    private let startedAt: TimeInterval
    private let output: (String) -> Void
    private var lastActivity: [Activity: TimeInterval] = [:]
    private var requestCount = 0
    private var messageServerCount = 0
    private var acceptedViewUri: String?
    private var lastNotifiedViewUri: String?

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

    func reportMessageServer(viewUri: String, accepted: Bool) {
        lock.lock()
        messageServerCount += 1
        let count = messageServerCount
        let acceptedComparison = Self.compareUri(viewUri, with: acceptedViewUri)
        let previousComparison = Self.compareUri(viewUri, with: lastNotifiedViewUri)
        if accepted { acceptedViewUri = viewUri }
        lastNotifiedViewUri = viewUri
        lock.unlock()
        let action = accepted ? "初回通知を採用" : "初回以降のため無視"
        emit("視聴用WS: messageServer通知 #\(count), 初回採用URLと比較=\(acceptedComparison), 前回通知URLと比較=\(previousComparison), 処理=\(action)")
    }

    private static func compareUri(_ uri: String, with previous: String?) -> String {
        guard let previous = previous else { return "比較対象なし" }
        return uri == previous ? "同一" : "変更あり"
    }

    /// URL・ヘッダー・IP アドレスは含めず、各 HTTP 試行の終了時に得られる計測値だけを出す。
    static func httpMetricsSummary(_ metrics: URLSessionTaskMetrics) -> [String] {
        let formatSeconds: (TimeInterval) -> String = { String(format: "%.3f", max(0, $0)) }
        let total = "task全体=\(formatSeconds(metrics.taskInterval.duration))秒, リダイレクト=\(metrics.redirectCount)回"
        guard !metrics.transactionMetrics.isEmpty else { return [total + ", 取引計測なし"] }
        return metrics.transactionMetrics.enumerated().map { index, transaction in
            let duration: (Date?, Date?) -> String = { start, end in
                guard let start = start else { return "記録なし" }
                guard let end = end else {
                    return "未完了(\(formatSeconds(metrics.taskInterval.end.timeIntervalSince(start)))秒経過)"
                }
                return formatSeconds(end.timeIntervalSince(start)) + "秒"
            }
            let protocolName: String
            switch transaction.networkProtocolName {
            case let name? where ["h2", "h3", "http/1.1", "http/1.0"].contains(name): protocolName = name
            case nil: protocolName = "記録なし"
            default: protocolName = "その他"
            }
            let source: String
            switch transaction.resourceFetchType {
            case .networkLoad: source = "ネットワーク"
            case .localCache: source = "キャッシュ"
            case .serverPush: source = "サーバープッシュ"
            default: source = "不明"
            }
            let status = (transaction.response as? HTTPURLResponse).map { String($0.statusCode) } ?? "なし"
            return [
                total, "取引=\(index + 1)/\(metrics.transactionMetrics.count)",
                "DNS=\(duration(transaction.domainLookupStartDate, transaction.domainLookupEndDate))",
                "接続(TLS含む)=\(duration(transaction.connectStartDate, transaction.connectEndDate))",
                "TLS=\(duration(transaction.secureConnectionStartDate, transaction.secureConnectionEndDate))",
                "要求送信=\(duration(transaction.requestStartDate, transaction.requestEndDate))",
                "応答待ち=\(duration(transaction.requestEndDate, transaction.responseStartDate))",
                "本文受信=\(duration(transaction.responseStartDate, transaction.responseEndDate))",
                "protocol=\(protocolName)", "接続再利用=\(transaction.isReusedConnection)", "取得元=\(source)", "status=\(status)"
            ].joined(separator: ", ")
        }
    }

    func emit(_ message: String) {
        lock.lock()
        let now = clock()
        let elapsed = Self.seconds(now - startedAt)
        let ages = Activity.allCases.map { activity in
            let age = lastActivity[activity].map { Self.seconds(now - $0) + "秒前" } ?? "未受信"
            return "\(activity.rawValue)=\(age)"
        }.joined(separator: ", ")
        let timestamp = timestampFormatter.string(from: Date())
        lock.unlock()

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
            case .requestRetryFailed(let retryError, _): return shouldRetry(retryError)
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
