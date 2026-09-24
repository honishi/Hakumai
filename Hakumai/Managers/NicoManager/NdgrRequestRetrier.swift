import Foundation
import Alamofire

// 再試行判定とタイムアウト監視は main queue に直列化する。
final class NdgrRequestRetrier: RequestRetrier, @unchecked Sendable {
    struct Policy {
        // Web プレイヤーに合わせ、同じ論理 HTTP に対し初回とは別に最大 5 回（c726f67）。
        // NicoManager の番組情報・WS を再取得する復旧上限とは別の層であり、全体で 5 回ではない。
        var maxRetries = 5
        var initialDelay: TimeInterval = 0.5
        var renewConnectionOnTimeout = true

        func delay(forRetry retry: Int) -> TimeInterval {
            guard retry > 1 else { return initialDelay }
            // Web プレイヤーと同じ倍率 1.5、±50% の揺らぎ。初回は固定 500ms。
            return initialDelay * pow(1.5, Double(retry - 1)) * (Bool.random() ? 1.5 : 0.5)
        }
    }

    struct ConnectionRenewal: Error {
        let delay: TimeInterval
    }

    private let report: (String) -> Void
    private let throttle: NdgrRequestThrottle
    private let timeout: NdgrStreamTimeout
    private let policy: Policy
    private var networkRetries = 0
    // タイムアウトで Request を作り直しても上限と診断上の試行番号を引き継ぐ。
    // Request ごとにカウンターを初期化すると、新規接続での失敗を無制限に繰り返してしまう。
    private var previousRequestRetries = 0
    var transportGeneration = 1
    var reportsSuccessfulMetrics = false

    private func totalRetries(for request: Request) -> Int {
        previousRequestRetries + request.retryCount
    }

    func takeConnectionRenewal(_ request: Request?, error: Error?) -> ConnectionRenewal? {
        guard let request = request,
              let error = error as? AFError, case .requestRetryFailed(let cause, _) = error,
              let renewal = cause as? ConnectionRenewal else { return nil }
        previousRequestRetries += request.retryCount + 1
        return renewal
    }

    init(throttle: NdgrRequestThrottle, timeout: NdgrStreamTimeout,
         policy: Policy = .init(), report: @escaping (String) -> Void) {
        self.throttle = throttle
        self.timeout = timeout
        self.report = report
        self.policy = policy
    }

    // main queue 上で、Alamofire の総回数と通信エラーだけの回数を区別して表示する。
    private func retryCountSummary(totalRetries: Int) -> String {
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
                self.timeout.stop()
                completion(.doNotRetry)
                return
            }
            let error = self.timeout.finishAttempt(error: error)
            self.reportAttemptMetrics(request, error: error)
            self.retry(request, error: error, completion: completion)
        }
    }

    func reportCompletedAttempt(_ request: Request?, error: Error?, receivedBytes: Int) {
        // 成功計測は HTTP の EOF 時点。本文を長く受信するため、ログ時刻はコメント再開時刻ではない。
        // receivedBytes は論理 HTTP 内の全試行の累計で、今回の試行だけの受信量ではない。
        // 通信失敗は retry() で記録済み。ここでは正常 EOF（未完フレーム検出を含む）を扱う。
        guard let request = request, request.error == nil else { return }
        let retries = totalRetries(for: request)
        guard error != nil || retries > 0 || reportsSuccessfulMetrics else { return }
        // 通常の履歴取得は省略し、失敗・再試行後と、接続更新後の初回だけを記録する。
        reportAttemptMetrics(request, error: error)
        if retries > 0 {
            report("HTTP再試行で回復, \(retryCountSummary(totalRetries: retries)), 受信=\(receivedBytes)bytes")
        }
    }

    private func reportAttemptMetrics(_ request: Request, error: Error?) {
        let result = error.map { ConnectionDiagnostics.errorSummary($0) } ?? "成功"
        let prefix = "HTTP試行計測: 試行=\(totalRetries(for: request) + 1), 結果=\(result), 通信世代=\(transportGeneration)"
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
        throttle.recordResponse(success: false)
        if request.response?.statusCode == 429 {
            throttle.retryRateLimited(request, completion: completion)
            return
        }
        guard
            let afError = error.asAFError,
            case .sessionTaskFailed(let underlyingError) = afError,
            case let code = (underlyingError as NSError).code,
            [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(code)
        else {
            log.debug("RequestRetrier > not retry")
            report("再試行対象外: \(ConnectionDiagnostics.errorSummary(error)) (\(retryCountSummary(totalRetries: totalRetries(for: request))))")
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
        if policy.renewConnectionOnTimeout, code == NSURLErrorTimedOut {
            // Alamofire の Request は別の Session へ移せないため、読み取り側で HTTP を作り直す。
            // このエラーは番組全体の再接続指示ではなく、NdgrTransport だけが扱う内部の制御用エラー。
            completion(.doNotRetryWithError(ConnectionRenewal(delay: delay)))
        } else {
            completion(.retryWithDelay(delay))
        }
    }
}
