import Foundation
import Alamofire

// 再試行判定とタイムアウト監視は main queue に直列化する。
final class NdgrRequestRetrier: RequestRetrier, @unchecked Sendable {
    struct Policy {
        var maxRetries = 5
        var initialDelay: TimeInterval = 0.5

        func delay(forRetry retry: Int) -> TimeInterval {
            guard retry > 1 else { return initialDelay }
            // Web プレイヤーと同じ倍率 1.5、±50% の揺らぎ。初回は固定 500ms。
            return initialDelay * pow(1.5, Double(retry - 1)) * (Bool.random() ? 1.5 : 0.5)
        }
    }

    private let report: (String) -> Void
    private let throttle: NdgrRequestThrottle?
    private let timeout: NdgrStreamTimeout?
    private let policy: Policy
    private var networkRetries = 0

    init(throttle: NdgrRequestThrottle? = nil, timeout: NdgrStreamTimeout? = nil,
         policy: Policy = .init(), report: @escaping (String) -> Void) {
        self.throttle = throttle
        self.timeout = timeout
        self.report = report
        self.policy = policy
    }

    // main queue 上で、Alamofire の総回数と通信エラーだけの回数を区別して表示する。
    func retryCountSummary(totalRetries: Int) -> String {
        "通信再試行済み=\(networkRetries)回, 総再試行済み（429含む）=\(totalRetries)回"
    }

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        DispatchQueue.main.async {
            guard !request.isCancelled else {
                self.timeout?.stop()
                completion(.doNotRetry)
                return
            }
            let error = self.timeout?.finishAttempt(error: error) ?? error
            self.reportAttemptMetrics(request, error: error)
            self.retry(request, error: error, completion: completion)
        }
    }

    func reportCompletedAttempt(_ request: Request?, error: Error?) {
        // 通信失敗は retry() で記録済み。ここでは正常 EOF（未完フレーム検出を含む）を扱う。
        guard let request = request, request.error == nil, error != nil || request.retryCount > 0 else { return }
        // 通常の履歴取得で大量のログを出さず、失敗と再試行後の回復だけを記録する。
        reportAttemptMetrics(request, error: error)
    }

    private func reportAttemptMetrics(_ request: Request, error: Error?) {
        let result = error.map { ConnectionDiagnostics.errorSummary($0) } ?? "成功"
        let prefix = "HTTP試行計測: 試行=\(request.retryCount + 1), 結果=\(result)"
        // metrics が欠ける環境でも、前の試行の値を今回の値として表示しない。
        guard request.allMetrics.count == request.tasks.count, let metrics = request.lastMetrics else {
            report("\(prefix), task計測なし（前の試行の計測値は使用しない）")
            return
        }
        for summary in ConnectionDiagnostics.httpMetricsSummary(metrics) {
            report("\(prefix), \(summary)")
        }
    }

    private func retry(_ request: Request, error: Error, completion: @escaping (RetryResult) -> Void) {
        log.debug("RequestRetrier > error: \(ConnectionDiagnostics.errorSummary(error))")
        throttle?.recordResponse(success: false)
        if request.response?.statusCode == 429, !request.isCancelled, let throttle = throttle {
            throttle.retryRateLimited(request, completion: completion)
            return
        }
        guard
            let afError = error.asAFError,
            case .sessionTaskFailed(let underlyingError) = afError,
            // Code=-1001 "The request timed out."
            // Code=-1005 "The network connection was lost."
            [-1001, -1005].contains((underlyingError as NSError).code)
        else {
            log.debug("RequestRetrier > not retry")
            report("再試行対象外: \(ConnectionDiagnostics.errorSummary(error)) (\(retryCountSummary(totalRetries: request.retryCount)))")
            completion(.doNotRetry)
            return
        }
        log.debug("RequestRetrier > perform retry")
        // 429 の再試行で、タイムアウト・切断の再試行枠を消費しない。
        guard networkRetries < policy.maxRetries else {
            report("再試行上限に到達: \(ConnectionDiagnostics.errorSummary(error)), 上限=\(policy.maxRetries)回")
            completion(.doNotRetryWithError(error))
            return
        }
        networkRetries += 1
        let delay = policy.delay(forRetry: networkRetries)
        report("\(networkRetries)回目の再試行を実行: \(ConnectionDiagnostics.errorSummary(error)), 上限=\(policy.maxRetries)回, 待機=\(String(format: "%.3f", delay))秒")
        completion(.retryWithDelay(delay))
    }
}
