import Foundation
import Alamofire

/// HTTP の各試行を main queue 上で監視する。429 の取得待ち行列では開始しない。
final class NdgrStreamTimeout: @unchecked Sendable {
    struct Limits {
        var header: TimeInterval
        var body: TimeInterval
    }

    struct Policy {
        // 2026-09 に調査したニコ生 Web プレイヤーの entry / message 設定に合わせる（eed070e）。
        // View の一律 10 秒化では正常なストリームも打ち切り得たため撤回した（3e9726b）。
        // コメント投稿がない時間と通信停止を区別し、HTTP のヘッダー待ち・本文の無受信時間を監視する。
        // Web 実装の将来の変更を自動追従する値ではない。調整時は正常な長時間受信も検証する。
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
    private var lastProgressAt: TimeInterval = 0
    private var didExpire = false

    init(limits: Limits, isActive: @escaping () -> Bool, report: @escaping (String) -> Void) {
        self.limits = limits
        self.isActive = isActive
        self.report = report
    }

    func observe(_ request: DataStreamRequest, onResponse: @escaping (HTTPURLResponse) -> Void) {
        request.onURLSessionTaskCreation { [weak request] task in
            guard let request = request else { return }
            self.start(task: task, request: request)
        }
        // Alamofire のヘッダー通知は一つだけ登録できるため、監視と本文の採否判定を同じ通知で行う。
        request.onHTTPResponse { response in
            self.receivedResponse(response)
            onResponse(response)
        }
    }

    private func start(task: URLSessionTask, request: DataStreamRequest) {
        // Request 作成時には 429 の adapt 待ちがあり得る。実際の task 作成から試行ごとに監視する。
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
        // protobuf の完成やコメント変換を待たず、生データの到着を進捗とする（分割フレームも正常）。
        guard !data.isEmpty, phase == .body, !didExpire else { return }
        // chunk ごとにタイマーを作り直さず、期限の判定時に最終受信からの経過で延長する。
        lastProgressAt = ProcessInfo.processInfo.systemUptime
    }

    /// task の期限切れによるキャンセルだけを、既存 retrier が扱える通信タイムアウトへ変換する。
    func finishAttempt(error: Error) -> Error {
        let underlying = error.asAFError?.underlyingError ?? error
        let code = (underlying as NSError).code
        let isNetworkError = (underlying as NSError).domain == NSURLErrorDomain
        let expired = didExpire && isNetworkError && code == NSURLErrorCancelled
        // URLSession 自身の -1001 は設定上限より早く返ることもある。「上限」は実測時間ではない。
        // 自前の監視による中止要求は「期限到達」、実際に確認した失敗は「タイムアウト」で区別する。
        if let phase = phase {
            if expired || (isNetworkError && code == NSURLErrorTimedOut) {
                reportTimeout(phase)
            } else if didExpire {
                report("\(phase.rawValue)期限到達後の終了: \(ConnectionDiagnostics.errorSummary(error)), タイムアウトへの変換なし")
            }
        }
        stop()
        return expired ? AFError.sessionTaskFailed(error: URLError(.timedOut)) : error
    }

    func stop() {
        deadline?.cancel()
        deadline = nil
        phase = nil
        task = nil
        request = nil
        didExpire = false
    }

    private func arm(_ phase: Phase) {
        self.phase = phase
        lastProgressAt = ProcessInfo.processInfo.systemUptime
        schedule(phase, after: duration(for: phase))
    }

    // 状態の更新と期限の実行はすべて main queue 上で行うため、cancel() 済みの期限は実行されない。
    private func schedule(_ phase: Phase, after delay: TimeInterval) {
        deadline?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isActive(), let request = self.request, !request.isCancelled,
                  let task = self.task, task === request.task, task.state == .running else { return }
            let remaining = self.lastProgressAt + self.duration(for: phase) - ProcessInfo.processInfo.systemUptime
            if remaining > 0 {
                self.schedule(phase, after: remaining)
                return
            }
            self.didExpire = true
            self.report("\(phase.rawValue)期限到達: 上限=\(self.duration(for: phase))秒, 当該HTTPの中止を要求")
            // Request.cancel() は Alamofire の再試行を禁止するため、今回の task のみ中止する。
            // Web 側の待機打ち切りと違い、未完の HTTP も中止してから再試行し、受信処理を残さない。
            task.cancel()
        }
        deadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func duration(for phase: Phase) -> TimeInterval {
        phase == .header ? limits.header : limits.body
    }

    private func reportTimeout(_ phase: Phase) {
        report("\(phase.rawValue)タイムアウト: 上限=\(duration(for: phase))秒, 終了原因を確認")
    }
}
