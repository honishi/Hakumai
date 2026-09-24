import Foundation
import Alamofire

/// View と Segment、および HTTP 再試行を同じ待ち行列に通す。
/// 状態は main queue に限定し、待機中も UI と視聴用 WS を動かし続ける。
/// 大量の履歴取得で 429 が起きても、番組全体を接続し直して同じ範囲を再取得しないための制御。
/// NdgrTransport の Session 更新をまたいで共有するが、別番組・新しい NDGR 接続とは共有しない。
final class NdgrRequestThrottle: RequestInterceptor, @unchecked Sendable {
    struct Policy {
        // 固定間隔の導入は履歴取得を大幅に遅くしたため、通常は元の実装同様に待機しない。
        // 429 時のみ減速し、成功応答の継続を確認して間隔を戻す（927f1d4、224e055）。
        var interval: TimeInterval = 0
        var retryDelays: [TimeInterval] = [10, 20, 40, 80]
        var maximumServerWait: TimeInterval = 300
        var stableDuration: TimeInterval = 30
        var stableResponseCount = 100
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
    private let onWait: () -> Void
    private var pending: [(URLRequest, (Result<URLRequest, Error>) -> Void)] = []
    private var wakeup: DispatchWorkItem?
    private var nextRequestAt: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0
    private var interval: TimeInterval
    private var cooldownCount = 0
    private var stoppedError: Error?
    private var isCoolingDown = false
    private var stableSince: TimeInterval?
    private var successfulResponses = 0
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private var sentRequests = 0
    private var waitStartedAt: TimeInterval?
    private var pacingWait: TimeInterval = 0
    private var cooldownWait: TimeInterval = 0

    init(policy: Policy = Policy(), onWait: @escaping () -> Void = {}, report: @escaping (String) -> Void) {
        self.policy = policy
        self.onWait = onWait
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
            self.accountWait(now: now)
            self.resetStability()
            let serverWait = Self.retryAfter(header) ?? 0
            guard serverWait <= self.policy.maximumServerWait else {
                self.report("NDGR HTTP 429: Retry-After=\(serverWait)秒が待機上限を超過、取得を中止")
                self.stop(error: Failure.serverWaitTooLong)
                completion(.doNotRetryWithError(Failure.serverWaitTooLong))
                return
            }
            // 同時に返った複数の 429 は一つの待機として数える。
            let startsNewWait = now >= self.cooldownUntil
            if startsNewWait {
                guard self.cooldownCount < self.policy.retryDelays.count else {
                    self.report("NDGR HTTP 429: 待機再試行上限\(self.cooldownCount)回、取得を中止（接続全体の再試行なし）")
                    self.stop(error: Failure.rateLimitExhausted)
                    completion(.doNotRetryWithError(Failure.rateLimitExhausted))
                    return
                }
                self.cooldownUntil = now + self.policy.retryDelays[self.cooldownCount]
                self.cooldownCount += 1
                // 初期値が 0 でも減速できるよう、最初の間隔は最低 10ms とする。
                self.interval = min(max(self.interval * 2, 0.01), 1)
            }
            self.cooldownUntil = max(self.cooldownUntil, now + serverWait)
            self.isCoolingDown = true
            // 待機理由は debug 表示を無効にしていても system message で伝える。同時 429 は一度だけ。
            if startsNewWait { self.onWait() }
            self.report("NDGR HTTP 429: 取得を一時停止、待機=\(String(format: "%.1f", self.cooldownUntil - now))秒, 待機回数=\(self.cooldownCount)/\(self.policy.retryDelays.count), Retry-After秒=\(serverWait), 再開後の取得間隔=\(self.interval)秒")
            self.drain()
            // 再試行も adapt を通るので、他の View/Segment とともに待機する。
            completion(.retry)
        }
    }

    /// 完了した HTTP 応答だけを数え、待機時間・無通信時間だけでは速度を戻さない。
    func recordResponse(success: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard stoppedError == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard success, !isCoolingDown, now >= cooldownUntil else {
            resetStability()
            return
        }
        guard interval > policy.interval else { return }
        if stableSince == nil { stableSince = now }
        successfulResponses += 1
        guard let since = stableSince, now - since >= policy.stableDuration,
              successfulResponses >= policy.stableResponseCount else { return }
        let previous = interval
        // 10ms まで回復したら初期値に戻す。半減だけでは 0 に到達しない。
        interval = max(policy.interval, interval <= 0.01 ? 0 : interval / 2)
        // 既に予約した次の送信も新しい間隔に合わせる。429 の待機期限は変更しない。
        nextRequestAt -= previous - interval
        report("NDGR取得速度を回復: 取得間隔=\(previous)→\(interval)秒, 安定時間=\(seconds(now - since))秒, 成功応答=\(successfulResponses)件, 待機回数=\(cooldownCount)/\(policy.retryDelays.count)（上限は維持）")
        resetStability()
        drain()
    }

    private func resetStability() {
        stableSince = nil
        successfulResponses = 0
    }

    /// 接続内の累計。並行リクエストの待ちを重複加算しない。
    func reportMetrics(context: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        let now = ProcessInfo.processInfo.systemUptime
        let wasWaiting = waitStartedAt != nil
        accountWait(now: now)
        if wasWaiting { waitStartedAt = now }
        report("NDGR取得集計: \(context), 接続内経過=\(seconds(now - startedAt))秒, HTTP送信許可=\(sentRequests)件（再試行含む）, 速度制限待機=\(seconds(pacingWait))秒, 429待機=\(seconds(cooldownWait))秒, 待機回数=\(cooldownCount), 取得間隔=\(interval)秒")
    }

    private func accountWait(now: TimeInterval) {
        guard let start = waitStartedAt else { return }
        cooldownWait += max(0, min(now, cooldownUntil) - start)
        pacingWait += max(0, now - max(start, cooldownUntil))
        waitStartedAt = nil
    }

    private func seconds(_ value: TimeInterval) -> String { String(format: "%.3f", value) }

    /// 手動停止・放送終了時、まだ送っていない HTTP を待機時間に関係なく解放する。
    func stop(error: Error = AFError.explicitlyCancelled) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard stoppedError == nil else { return }
        reportMetrics(context: "取得停止")
        waitStartedAt = nil
        stoppedError = error
        wakeup?.cancel()
        wakeup = nil
        let requests = pending
        pending.removeAll()
        if !requests.isEmpty { report("NDGR取得待機を取り消す: \(requests.count)件") }
        for (_, completion) in requests { completion(.failure(error)) }
    }

    private func drain() {
        let now = ProcessInfo.processInfo.systemUptime
        accountWait(now: now)
        wakeup?.cancel()
        wakeup = nil
        guard stoppedError == nil, !pending.isEmpty else { return }
        let delay = max(nextRequestAt, cooldownUntil) - now
        if delay > 0 {
            waitStartedAt = now
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
        sentRequests += 1
        nextRequestAt = now + interval
        completion(.success(request))
        if !pending.isEmpty { drain() }
    }

    static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if let seconds = Double(value), seconds.isFinite, seconds >= 0 { return seconds }
        guard let date = httpDateFormatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}
