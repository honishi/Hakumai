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
            self.retry(request, error: error, completion: completion)
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
            report("再試行対象外: \(ConnectionDiagnostics.errorSummary(error)) (再試行済み=\(request.retryCount))")
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
