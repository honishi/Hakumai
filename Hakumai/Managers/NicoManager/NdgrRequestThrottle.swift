import Foundation
import Alamofire

/// View と Segment、および HTTP 再試行を同じ待ち行列に通す。
/// 状態は main queue に限定し、待機中も UI と視聴用 WS を動かし続ける。
final class NdgrRequestThrottle: RequestInterceptor, @unchecked Sendable {
    struct Policy {
        // サーバーの公称制限値ではなく、履歴取得のバーストを避けるための初期値。
        var interval: TimeInterval = 0.1
        var retryDelays: [TimeInterval] = [10, 20, 40, 80]
        var maximumServerWait: TimeInterval = 300
    }

    enum Failure: Error {
        case rateLimitExhausted
        case serverWaitTooLong

        var diagnosticSummary: String {
            switch self {
            case .rateLimitExhausted: return "HTTP 429: 待機再試行上限に到達"
            case .serverWaitTooLong: return "HTTP 429: サーバー指定の待機時間が上限を超過"
            }
        }
    }

    private let policy: Policy
    private let report: (String) -> Void
    private var pending: [(URLRequest, (Result<URLRequest, Error>) -> Void)] = []
    private var wakeup: DispatchWorkItem?
    private var nextRequestAt: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0
    private var interval: TimeInterval
    private var cooldownCount = 0
    private var stoppedError: Error?
    private var isCoolingDown = false

    init(policy: Policy = Policy(), report: @escaping (String) -> Void) {
        self.policy = policy
        self.report = report
        interval = policy.interval
    }

    func adapt(_ urlRequest: URLRequest, for session: Session,
               completion: @escaping (Result<URLRequest, Error>) -> Void) {
        DispatchQueue.main.async {
            if let error = self.stoppedError {
                completion(.failure(error))
                return
            }
            self.pending.append((urlRequest, completion))
            self.drain()
        }
    }

    /// 呼び出し元の HTTP retrier から委譲する。429 以外の既存の再試行条件は変更しない。
    func retryRateLimited(_ request: Request, completion: @escaping (RetryResult) -> Void) {
        let header = request.response?.value(forHTTPHeaderField: "Retry-After")
        DispatchQueue.main.async {
            if let error = self.stoppedError {
                completion(.doNotRetryWithError(error))
                return
            }
            guard !request.isCancelled else {
                completion(.doNotRetry)
                return
            }
            let now = ProcessInfo.processInfo.systemUptime
            let serverWait = Self.retryAfter(header) ?? 0
            guard serverWait <= self.policy.maximumServerWait else {
                self.report("NDGR HTTP 429: Retry-After=\(serverWait)秒が待機上限を超過、取得を中止")
                self.stop(error: Failure.serverWaitTooLong)
                completion(.doNotRetryWithError(Failure.serverWaitTooLong))
                return
            }
            // 同時に返った複数の 429 は一つの待機として数える。
            if now >= self.cooldownUntil {
                guard self.cooldownCount < self.policy.retryDelays.count else {
                    self.report("NDGR HTTP 429: 待機再試行上限\(self.cooldownCount)回、取得を中止（接続全体の再試行なし）")
                    self.stop(error: Failure.rateLimitExhausted)
                    completion(.doNotRetryWithError(Failure.rateLimitExhausted))
                    return
                }
                self.cooldownUntil = now + self.policy.retryDelays[self.cooldownCount]
                self.cooldownCount += 1
                self.interval = min(max(self.interval * 2, self.policy.interval), 1)
            }
            self.cooldownUntil = max(self.cooldownUntil, now + serverWait)
            self.isCoolingDown = true
            self.report("NDGR HTTP 429: 取得を一時停止、待機=\(String(format: "%.1f", self.cooldownUntil - now))秒, 待機回数=\(self.cooldownCount)/\(self.policy.retryDelays.count), Retry-After秒=\(serverWait), 再開後の取得間隔=\(self.interval)秒")
            self.drain()
            // 再試行も adapt を通るので、他の View/Segment とともに待機する。
            completion(.retry)
        }
    }

    /// 手動停止・放送終了時、まだ送っていない HTTP を待機時間に関係なく解放する。
    func stop(error: Error = AFError.explicitlyCancelled) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard stoppedError == nil else { return }
        stoppedError = error
        wakeup?.cancel()
        wakeup = nil
        let requests = pending
        pending.removeAll()
        if !requests.isEmpty { report("NDGR取得待機を取り消す: \(requests.count)件") }
        for (_, completion) in requests { completion(.failure(error)) }
    }

    private func drain() {
        wakeup?.cancel()
        wakeup = nil
        guard stoppedError == nil, !pending.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let delay = max(nextRequestAt, cooldownUntil) - now
        if delay > 0 {
            let work = DispatchWorkItem { [weak self] in self?.drain() }
            wakeup = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return
        }
        if isCoolingDown {
            isCoolingDown = false
            report("NDGR HTTP 429: 待機終了、同じ取得位置からHTTP再試行（視聴用WSを維持）, 取得間隔=\(interval)秒")
        }
        let (request, completion) = pending.removeFirst()
        nextRequestAt = now + interval
        completion(.success(request))
        if !pending.isEmpty { drain() }
    }

    static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if let seconds = Double(value), seconds.isFinite, seconds >= 0 { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
