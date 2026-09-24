import Foundation
import Alamofire

// 接続・停止・読み取りの状態更新は main queue に限定する。
/// NDGR 接続内の HTTP セッションを管理し、使用期限またはタイムアウトで接続プールを更新する。
/// 2026-09 の実測では、再利用した HTTP/3 接続で応答待ちが繰り返しタイムアウトし、
/// 新しい URLSession に替えると回復した（ab24a93）。原因が OS・サーバー・経路のどこかは未確定。
/// 同じ Session 内の HTTP 再試行では接続が再利用され得るため、ここで Session 自体を交換する。
final class NdgrTransport: @unchecked Sendable {
    private final class Lease {
        let session: Session
        let generation: Int
        let createdAt: TimeInterval
        var activeReaders = 0
        var hasStartedRequest = false
        init(session: Session, generation: Int, createdAt: TimeInterval) {
            self.session = session
            self.generation = generation
            self.createdAt = createdAt
        }
    }

    let throttle: NdgrRequestThrottle
    // 約 14〜15 分ごとの不調を観測したため、それより短い 5 分を予防更新の初期値にした（8497d20）。
    // サーバー仕様や QUIC の寿命ではなく、実測に基づく回避策。更新後は長時間の無障害ログを得たが、
    // 因果関係は未確定なので、変更時はタイムアウト件数と更新後の接続再利用・応答待ちを比較する。
    let maximumSessionAge: TimeInterval
    private let configuration: URLSessionConfiguration
    private let clock: () -> TimeInterval
    private var current: Lease
    private var retired: [Lease] = []
    private var readers: [UUID: Task<Void, Never>] = [:]
    private var acceptsRequests = true

    init(configuration: URLSessionConfiguration, throttle: NdgrRequestThrottle,
         maximumSessionAge: TimeInterval = 5 * 60,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.configuration = configuration
        self.throttle = throttle
        self.maximumSessionAge = maximumSessionAge
        self.clock = clock
        current = Lease(session: Self.makeSession(configuration: configuration, throttle: throttle),
                        generation: 1, createdAt: clock())
    }

    private static func makeSession(configuration: URLSessionConfiguration, throttle: NdgrRequestThrottle) -> Session {
        // Alamofire Session の新設により URLSession も新設される。接続確立は HTTP 開始時に OS が行う。
        // 新規接続の使用は metrics の isReusedConnection で検証する。HTTP/3 を無効にする処理ではない。
        // 429 の待機・減速状態は新旧 Session で共有し、接続更新によって制限を迂回しない。
        Session(configuration: configuration, startRequestsImmediately: false, interceptor: throttle)
    }

    func stopNewRequests() {
        dispatchPrecondition(condition: .onQueue(.main))
        acceptsRequests = false
        throttle.stop()
    }

    func cancelAllRequests() {
        stopNewRequests()
        for reader in readers.values { reader.cancel() }
        for lease in retired + [current] { lease.session.cancelAllRequests() }
    }

    @MainActor
    func stream<T>(report: @escaping (String) -> Void,
                   installStop: (AsyncThrowingStream<T, Error>.Continuation) -> Void,
                   makeStream: @escaping (Session, Int, Bool) -> AsyncThrowingStream<T, Error>) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            let reader = Task { @MainActor in
                defer { self.readers.removeValue(forKey: id) }
                do {
                    while true {
                        try Task.checkCancellation()
                        guard self.acceptsRequests else { throw CancellationError() }
                        self.renewIfExpired(report: report)
                        let lease = self.current
                        let reportMetrics = lease.generation > 1 && !lease.hasStartedRequest
                        lease.hasStartedRequest = true
                        lease.activeReaders += 1
                        do {
                            // catch より先に解放し、更新判定の時点で使用中の読み取りに数えない。
                            defer { self.release(lease) }
                            for try await message in makeStream(lease.session, lease.generation, reportMetrics) {
                                try Task.checkCancellation()
                                continuation.yield(message)
                            }
                            break
                        } catch {
                            try Task.checkCancellation()
                            guard let renewal = error as? NdgrRequestRetrier.ConnectionRenewal else { throw error }
                            guard self.acceptsRequests else { throw CancellationError() }
                            self.renew(after: lease, report: report)
                            try await Task.sleep(nanoseconds: UInt64(renewal.delay * 1_000_000_000))
                        }
                    }
                    try Task.checkCancellation()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            readers[id] = reader
            continuation.onTermination = { @Sendable _ in reader.cancel() }
            // 終了通知は再試行の待機中にも、この論理 HTTP 全体を止める。
            installStop(continuation)
        }
    }

    private func renewIfExpired(report: (String) -> Void) {
        // 測るのは Session 作成からの単調時計上の経過。物理接続の年齢や最終受信からの時間ではない。
        // 新規の論理 HTTP 割り当て時にだけ確認するため、300 秒を少し超えるのは正常。
        // 受信中のストリームや、その Request 内の Alamofire 再試行を期限だけで中断・移動しない。
        let age = clock() - current.createdAt
        guard age >= maximumSessionAge else { return }
        let previous = current
        replaceCurrent()
        report("通信接続を予防更新: 世代=\(previous.generation)→\(current.generation), 理由=Session使用期限, 経過=\(String(format: "%.3f", age))秒, 上限=\(maximumSessionAge)秒, 並行受信=\(previous.activeReaders)件は継続")
    }

    private func renew(after failed: Lease, report: (String) -> Void) {
        if failed === current {
            replaceCurrent()
            report("通信接続を更新: 世代=\(failed.generation)→\(current.generation), タイムアウト後の再試行に新しいURLSessionを使用, 並行受信は継続")
        } else {
            // 同じ旧 Session の複数 HTTP が同時に失敗しても、交換済みの接続を重ねて破棄しない。
            report("通信接続は更新済み: 世代=\(failed.generation)→\(current.generation), 他のHTTPが作成したURLSessionを使用")
        }
    }

    private func replaceCurrent() {
        let previous = current
        retired.append(previous)
        current = Lease(session: Self.makeSession(configuration: configuration, throttle: throttle),
                        generation: previous.generation + 1, createdAt: clock())
        retireIfUnused(previous)
    }

    private func release(_ lease: Lease) {
        lease.activeReaders -= 1
        retireIfUnused(lease)
    }

    private func retireIfUnused(_ lease: Lease) {
        // 古い接続を即座にキャンセルすると、並行受信中の Segment まで失い、不要な復旧を招く。
        // 新規割り当てから外した後も読み取り完了まで保持し、最後の読み取りが離れた時点で終了する。
        guard lease !== current, lease.activeReaders == 0 else { return }
        lease.session.session.finishTasksAndInvalidate()
        retired.removeAll { $0 === lease }
    }
}
