import Foundation
import Alamofire

// 接続・停止・読み取りの状態更新は main queue に限定する。
/// NDGR 接続内の HTTP セッションを管理する。タイムアウト後は新しい接続プールで再試行する。
final class NdgrTransport: @unchecked Sendable {
    private final class Lease {
        let session: Session
        let generation: Int
        var readers = 0
        init(session: Session, generation: Int) {
            self.session = session
            self.generation = generation
        }
    }

    let throttle: NdgrRequestThrottle
    private let configuration: URLSessionConfiguration
    private var current: Lease
    private var retired: [Lease] = []
    private var readers: [UUID: Task<Void, Never>] = [:]
    private var acceptsRequests = true

    init(configuration: URLSessionConfiguration, throttle: NdgrRequestThrottle) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.configuration = configuration
        self.throttle = throttle
        current = Lease(session: Session(configuration: configuration, startRequestsImmediately: false,
                                         interceptor: throttle), generation: 1)
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
                   makeStream: @escaping (Session, Int) -> AsyncThrowingStream<T, Error>) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            let reader = Task { @MainActor in
                defer { self.readers.removeValue(forKey: id) }
                do {
                    while true {
                        try Task.checkCancellation()
                        guard self.acceptsRequests else { throw CancellationError() }
                        let lease = self.current
                        lease.readers += 1
                        do {
                            for try await message in makeStream(lease.session, lease.generation) {
                                try Task.checkCancellation()
                                continuation.yield(message)
                            }
                            self.release(lease)
                            break
                        } catch {
                            self.release(lease)
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

    private func renew(after failed: Lease, report: (String) -> Void) {
        if failed === current {
            retired.append(current)
            current = Lease(session: Session(configuration: configuration, startRequestsImmediately: false,
                                             interceptor: throttle), generation: current.generation + 1)
            report("通信接続を更新: 世代=\(failed.generation)→\(current.generation), タイムアウト後の再試行に新しいURLSessionを使用, 並行受信は継続")
            retireIfUnused(failed)
        } else {
            report("通信接続は更新済み: 世代=\(failed.generation)→\(current.generation), 他のHTTPが作成したURLSessionを使用")
        }
    }

    private func release(_ lease: Lease) {
        lease.readers -= 1
        retireIfUnused(lease)
    }

    private func retireIfUnused(_ lease: Lease) {
        guard lease !== current, lease.readers == 0 else { return }
        lease.session.session.finishTasksAndInvalidate()
        retired.removeAll { $0 === lease }
    }
}
