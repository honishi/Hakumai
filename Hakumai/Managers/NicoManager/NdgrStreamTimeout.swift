import Foundation
import Alamofire

/// HTTP の各試行を main queue 上で監視する。429 の取得待ち行列では開始しない。
final class NdgrStreamTimeout: @unchecked Sendable {
    struct Limits {
        var header: TimeInterval
        var body: TimeInterval
    }

    struct Policy {
        // ニコ生 Web プレイヤーの entry / message 設定に合わせる。
        var view = Limits(header: 60, body: 60)
        var segment = Limits(header: 10, body: 30)

        func limits(for activity: ConnectionDiagnostics.Activity) -> Limits {
            activity == .view ? view : segment
        }
    }

    private enum Phase: String {
        case header = "ヘッダー待ち"
        case body = "本文待ち"
    }

    private let limits: Limits
    private let isActive: () -> Bool
    private let report: (String) -> Void
    private weak var request: DataStreamRequest?
    private weak var task: URLSessionTask?
    private var phase: Phase?
    private var deadline: DispatchWorkItem?
    private var generation = 0
    private var didExpire = false

    init(limits: Limits, isActive: @escaping () -> Bool, report: @escaping (String) -> Void) {
        self.limits = limits
        self.isActive = isActive
        self.report = report
    }

    func observe(_ request: DataStreamRequest) {
        request.onURLSessionTaskCreation { [weak request] task in
            guard let request = request else { return }
            self.start(task: task, request: request)
        }
        request.onHTTPResponse { response in self.receivedResponse(response) }
    }

    private func start(task: URLSessionTask, request: DataStreamRequest) {
        stop()
        guard isActive(), !request.isCancelled else { return }
        self.task = task
        self.request = request
        arm(.header)
    }

    private func receivedResponse(_ response: HTTPURLResponse) {
        // 429 / HTTP エラーは既存の検証・バックオフに渡す。
        guard (200..<300).contains(response.statusCode) else {
            stop()
            return
        }
        guard phase != nil, !didExpire else { return }
        arm(.body)
    }

    func receivedData(_ data: Data) {
        guard !data.isEmpty, phase == .body, !didExpire else { return }
        arm(.body)
    }

    /// task の期限切れによるキャンセルだけを、既存 retrier が扱える通信タイムアウトへ変換する。
    func finishAttempt(error: Error) -> Error {
        let underlying = error.asAFError?.underlyingError ?? error
        let code = (underlying as NSError).code
        let isNetworkError = (underlying as NSError).domain == NSURLErrorDomain
        let expired = didExpire && isNetworkError && code == NSURLErrorCancelled
        if !didExpire, isNetworkError, code == NSURLErrorTimedOut, let phase = phase {
            reportTimeout(phase)
        }
        stop()
        return expired ? AFError.sessionTaskFailed(error: URLError(.timedOut)) : error
    }

    func stop() {
        generation += 1
        deadline?.cancel()
        deadline = nil
        phase = nil
        task = nil
        request = nil
        didExpire = false
    }

    private func arm(_ phase: Phase) {
        deadline?.cancel()
        generation += 1
        let expectedGeneration = generation
        self.phase = phase
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.generation == expectedGeneration,
                  self.isActive(), let request = self.request, !request.isCancelled,
                  let task = self.task, task === request.task, task.state == .running else { return }
            self.didExpire = true
            self.reportTimeout(phase)
            // Request.cancel() は Alamofire の再試行を禁止するため、今回の task のみ中止する。
            task.cancel()
        }
        deadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration(for: phase), execute: work)
    }

    private func duration(for phase: Phase) -> TimeInterval {
        phase == .header ? limits.header : limits.body
    }

    private func reportTimeout(_ phase: Phase) {
        report("\(phase.rawValue)タイムアウト: 上限=\(duration(for: phase))秒")
    }
}
