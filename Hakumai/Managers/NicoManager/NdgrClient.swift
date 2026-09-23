//
//  NdgrClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2024/08/03.
//  Copyright © 2024 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import SwiftProtobuf

final class NdgrClient: NdgrClientType {
    // Public Properties
    weak var delegate: NdgrClientDelegate?

    // Private Properties
    private let configuration: URLSessionConfiguration
    private let endDrainTimeout: TimeInterval
    private let throttlePolicy: NdgrRequestThrottle.Policy
    private let timeoutPolicy: NdgrStreamTimeout.Policy
    private let retryPolicy: NdgrRequestRetrier.Policy
    private var streamSession: NdgrTransport?
    private var streamTask: Task<Void, Never>?
    private var activeDiagnostics: ConnectionDiagnostics?
    private var receivedMessageMetaIds = Set<String>()
    private var resumeAt: Int?
    private var connected = false
    private var duplicateCount = 0

    init(delegate: NdgrClientDelegate? = nil, configuration: URLSessionConfiguration = .af.default,
         endDrainTimeout: TimeInterval = 5, throttlePolicy: NdgrRequestThrottle.Policy = .init(),
         timeoutPolicy: NdgrStreamTimeout.Policy = .init(), retryPolicy: NdgrRequestRetrier.Policy = .init()) {
        self.delegate = delegate
        self.configuration = configuration
        self.endDrainTimeout = endDrainTimeout
        self.throttlePolicy = throttlePolicy
        self.timeoutPolicy = timeoutPolicy
        self.retryPolicy = retryPolicy
        configuration.headers.add(.userAgent(commonUserAgentValue))
    }
}

// 接続の切り替えと delegate 通知は main queue に直列化する。
extension NdgrClient {
    func connect(viewUri: URL, beginTime: Date, diagnostics: ConnectionDiagnostics, resuming: Bool = false) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.connect(viewUri: viewUri, beginTime: beginTime,
                                                    diagnostics: diagnostics, resuming: resuming) }
            return
        }
        disconnect()
        if !resuming {
            // 復旧では再開位置と meta ID を残す。途中の Segment を再取得しても表示済みコメントを重ねない。
            // 手動接続は別の受信セッションなので、同じ番組への接続でも両方をリセットする。
            receivedMessageMetaIds.removeAll()
            resumeAt = Int(beginTime.timeIntervalSince1970)
        }
        let throttle = NdgrRequestThrottle(policy: throttlePolicy, onWait: { [weak self] in
            guard let self = self, self.activeDiagnostics === diagnostics else { return }
            self.delegate?.ndgrClientWillWaitForRateLimit(self, diagnostics: diagnostics)
        }, report: { diagnostics.emit($0) })
        let session = NdgrTransport(configuration: configuration, throttle: throttle)
        let startAt = resumeAt ?? Int(beginTime.timeIntervalSince1970)
        streamSession = session
        activeDiagnostics = diagnostics
        connected = false
        duplicateCount = 0
        diagnostics.emit("NDGR取得制御: 最小間隔=\(throttlePolicy.interval)秒, HTTP 429待機再試行上限=\(throttlePolicy.retryDelays.count)回")
        diagnostics.emit("NDGR通信再試行: 上限=\(retryPolicy.maxRetries)回（初回取得を除く）, 初回待機=\(retryPolicy.initialDelay)秒, 以降は倍率1.5・±50%の揺らぎ")
        diagnostics.emit("NDGR通信接続更新: タイムアウト後のURLSession更新=\(retryPolicy.renewConnectionOnTimeout), HTTP計測の接続再利用で効果を確認")
        diagnostics.emit("NDGR通信接続予防更新: Session再利用上限=\(session.maximumSessionAge)秒（作成時から）, 新規HTTP割り当て時に確認, 受信中の通信は継続, 更新後の初回HTTPを計測")
        diagnostics.emit("NDGR開始 (View: ヘッダー待ち=\(timeoutPolicy.view.header)秒, 本文待ち=\(timeoutPolicy.view.body)秒 / Segment: ヘッダー待ち=\(timeoutPolicy.segment.header)秒, 本文待ち=\(timeoutPolicy.segment.body)秒), 再開=\(resuming), at=\(startAt)")
        streamTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let reason: NdgrTermination
            do {
                try await self.forwardPlaylist(uri: viewUri, from: startAt, diagnostics: diagnostics, session: session)
                reason = .missingNext
            } catch NdgrStreamError.programEnded {
                reason = .programEnded
            } catch {
                reason = .failure(error)
            }
            guard self.activeDiagnostics === diagnostics, !Task.isCancelled else { return }
            diagnostics.emit("NDGR終了通知: \(Self.summary(reason)), 重複除外=\(self.duplicateCount)")
            self.disconnect()
            self.delegate?.ndgrClientDidDisconnect(self, diagnostics: diagnostics, reason: reason)
        }
    }

    func disconnect() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.disconnect() }
            return
        }
        // 古い Session のキャンセルが新しい接続の HTTP を巻き込まないよう、接続ごとに分離する。
        activeDiagnostics?.emit("NDGR停止: 受信Taskと当該接続のHTTPをキャンセル, 重複除外=\(duplicateCount)")
        activeDiagnostics = nil
        streamTask?.cancel()
        streamTask = nil
        streamSession?.cancelAllRequests()
        streamSession = nil
    }

    private static func summary(_ reason: NdgrTermination) -> String {
        switch reason {
        case .programEnded: return "サーバーから放送終了を確認"
        case .missingNext: return "次の取得位置なし（放送終了は未確認）"
        case .failure(let error): return "通信・解析失敗 \(ConnectionDiagnostics.errorSummary(error))"
        }
    }
}

private extension NdgrClient {
    @MainActor
    func forwardPlaylist(uri: URL, from: Int, diagnostics: ConnectionDiagnostics, session: NdgrTransport) async throws {
        var next: Int? = from
        var segmentCount = 0
        let chatHistory = ChatHistory()
        // 失敗時も履歴本体は渡す。件数の確定は履歴完了または Manager の最終切断で行う。
        defer { emitChatHistoryIfExists(chatHistory: chatHistory, diagnostics: diagnostics) }
        let latestHistoryTime = Int(Date().timeIntervalSince1970) - 16 * 4

        while let current = next {
            try Task.checkCancellation()
            chatHistory.isFetching = current < latestHistoryTime
            if !chatHistory.isFetching {
                finishChatHistory(chatHistory, diagnostics: diagnostics)
            }
            let result = try await forwardView(uri: uri.appending("at", value: String(current)),
                                               chatHistory: chatHistory, diagnostics: diagnostics, session: session)
            segmentCount += result.segmentCount
            next = result.next
            if chatHistory.isFetching {
                delegate?.ndgrClientReceivingChatHistory(self, requestCount: segmentCount,
                                                         totalChatCount: chatHistory.totalCount, diagnostics: diagnostics)
            }
            // 再開位置より前の履歴を Manager に退避する。画面への一括表示前に再接続しても失わないため。
            emitChatHistoryIfExists(chatHistory: chatHistory, diagnostics: diagnostics)
            try Task.checkCancellation()
            if let next = next { resumeAt = next }
        }
        diagnostics.emit("NDGR Viewループ終了: 次の取得位置なし (segments=\(segmentCount))")
    }

    @MainActor
    // swiftlint:disable:next cyclomatic_complexity
    func forwardView(uri: URL, chatHistory: ChatHistory, diagnostics: ConnectionDiagnostics,
                     session: NdgrTransport) async throws -> (next: Int?, segmentCount: Int) {
        let view = ViewIteration()
        defer { view.cancelEndDeadline() }
        var next: Int?
        var segmentCount = 0
        // Segment の完了を待ってから再開位置を進め、取得途中のコメントを飛ばさない。
        // Web プレイヤーの View 先行取得とは意図的に異なる。高速化する場合も未完了 Segment の
        // 再取得を保証すること。単に next を先に保存すると、復旧時の重複排除だけでは欠落を防げない。
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var activeSegments = 0
                let entries = retrieve(uri: uri, messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self,
                                       activity: .view, diagnostics: diagnostics, session: session, view: view)
                entryLoop: for try await entry in entries {
                    try Task.checkCancellation()
                    if view.programEnded { break entryLoop }
                    if let failure = view.failure { throw failure }
                    guard let entry = entry.entry else { continue }
                    switch entry {
                    case .backward, .previous: continue
                    case .segment(let segment):
                        guard let url = URL(string: segment.uri) else { throw NdgrStreamError.invalidSegmentURL }
                        if activeSegments >= 8 {
                            try await group.next()
                            activeSegments -= 1
                            if view.programEnded { break entryLoop }
                        }
                        segmentCount += 1
                        activeSegments += 1
                        view.pendingSegments += 1
                        group.addTask {
                            try await self.pullSegment(uri: url, chatHistory: chatHistory,
                                                       diagnostics: diagnostics, session: session, view: view)
                        }
                    case .next(let marker): next = Int(marker.at)
                    }
                }
                try await group.waitForAll()
            }
        } catch {
            // 終了通知と通信失敗が競合しても、確認済みの終了を復旧に戻さない。
            if !view.programEnded { throw error }
        }
        try Task.checkCancellation()
        if view.programEnded {
            diagnostics.emit("NDGR終了待ち完了: 取得失敗Segment=\(view.failedSegments), 取得済みコメントを通知して終了")
            throw NdgrStreamError.programEnded
        }
        return (next, segmentCount)
    }

    @MainActor
    func pullSegment(uri: URL, chatHistory: ChatHistory, diagnostics: ConnectionDiagnostics,
                     session: NdgrTransport, view: ViewIteration) async throws {
        defer { view.pendingSegments -= 1 }
        do {
            try await pullMessages(uri: uri, chatHistory: chatHistory, diagnostics: diagnostics, session: session, view: view)
        } catch {
            try Task.checkCancellation()
            if view.programEnded {
                view.failedSegments += 1
                diagnostics.emit("NDGR終了待ち: Segment取得失敗、放送終了を優先: \(ConnectionDiagnostics.errorSummary(error)), 未完了Segment(当該含む)=\(view.pendingSegments), 取得失敗累計=\(view.failedSegments)")
                return
            }
            diagnostics.emit("NDGR Segment失敗 → View待機を解除: \(ConnectionDiagnostics.errorSummary(error))")
            view.fail(error)
            throw error
        }
    }

    @MainActor
    func finishChatHistory(_ history: ChatHistory, diagnostics: ConnectionDiagnostics) {
        guard activeDiagnostics === diagnostics, !history.didFinish else { return }
        streamSession?.throttle.reportMetrics(context: "履歴取得完了")
        emitChatHistoryIfExists(chatHistory: history, diagnostics: diagnostics)
        history.didFinish = true
        delegate?.ndgrClientDidFinishChatHistory(self, diagnostics: diagnostics)
    }

    @MainActor
    func emitChatHistoryIfExists(chatHistory: ChatHistory, diagnostics: ConnectionDiagnostics) {
        guard activeDiagnostics === diagnostics, !chatHistory.isEmpty else { return }
        receivedMessageMetaIds.formUnion(chatHistory.metaIds)
        delegate?.ndgrClientDidReceiveChatHistory(self, chats: chatHistory.chats, diagnostics: diagnostics)
        chatHistory.removeAll()
    }

    @MainActor
    func pullMessages(uri: URL, chatHistory: ChatHistory, diagnostics: ConnectionDiagnostics,
                      session: NdgrTransport, view: ViewIteration) async throws {
        let messages = retrieve(uri: uri, messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage.self,
                                activity: .segment, diagnostics: diagnostics, session: session)
        for try await message in messages {
            try Task.checkCancellation()
            guard activeDiagnostics === diagnostics, let payload = message.payload else { continue }
            let chat: Chat?
            switch payload {
            case .message(let message): chat = message.toChat()
            case .state(let state):
                if state.isDisconnect() {
                    // 新規取得を止め、開始済みの Segment だけを上限時間内で受け取り切る。
                    view.endProgram(timeout: endDrainTimeout, diagnostics: diagnostics, session: session)
                    return
                }
                chat = state.toChat()
            case .signal: chat = nil
            }
            if !connected {
                connected = true
                diagnostics.emit("NDGR実データ受信 → 接続成功")
                delegate?.ndgrClientDidConnect(self, diagnostics: diagnostics)
            }
            guard let chat = chat else { continue }
            emit(chat: chat, metaId: message.meta.id, history: chatHistory, diagnostics: diagnostics)
        }
        try Task.checkCancellation()
    }

    @MainActor
    func emit(chat: Chat, metaId: String, history: ChatHistory, diagnostics: ConnectionDiagnostics) {
        if !metaId.isEmpty && (receivedMessageMetaIds.contains(metaId) || history.metaIds.contains(metaId)) {
            duplicateCount += 1
            return
        }
        if history.isFetching {
            history.append(chat)
            if !metaId.isEmpty { history.metaIds.insert(metaId) }
        } else {
            if !metaId.isEmpty { receivedMessageMetaIds.insert(metaId) }
            diagnostics.record(.comment)
            delegate?.ndgrClientDidReceiveChat(self, chat: chat, diagnostics: diagnostics)
        }
    }
}

// Low layer for chunked network I/O.
private extension NdgrClient {
    // #1. 指定された uri を stream として listen しつつ、
    // 逐一 protobuf message として parse したものを stream として返す。
    // swiftlint:disable function_body_length
    @MainActor
    func retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type,
        activity: ConnectionDiagnostics.Activity,
        diagnostics: ConnectionDiagnostics,
        session: NdgrTransport,
        view: ViewIteration? = nil
    ) -> AsyncThrowingStream<T, Error> {
        // log.debug("\(uri.absoluteString)")
        let requestID = diagnostics.nextRequestID()
        let label = "\(activity.rawValue) HTTP#\(requestID)"
        var receivedBytes = 0
        let limits = timeoutPolicy.limits(for: activity)
        let timeout = NdgrStreamTimeout(limits: limits, isActive: { [weak self] in
            self?.activeDiagnostics === diagnostics
        }, report: { diagnostics.emit("\(label): \($0)") })
        // Session を交換する makeStream の外に置き、同じ URI の再試行上限を交換後も維持する。
        let retrier = NdgrRequestRetrier(throttle: session.throttle,
                                         timeout: timeout, policy: retryPolicy) { message in
            diagnostics.emit("\(label): \(message)")
        }

        return session.stream(report: { diagnostics.emit("\(label): \($0)") }, installStop: { continuation in
            view?.stop = { continuation.finish(throwing: $0) }
        }, makeStream: { [weak self] attemptSession, generation, reportMetrics in
            retrier.transportGeneration = generation
            retrier.reportsSuccessfulMetrics = reportMetrics
            var unread: Data?
            var parsedRetryCount = 0
            return AsyncThrowingStream { continuation in
                let request = attemptSession.streamRequest(
                    uri,
                    method: .get,
                    interceptor: Interceptor(retriers: [retrier]),
                    // OS 側の補助タイムアウト。ヘッダー／本文の別々の期限は NdgrStreamTimeout が担う。
                    requestModifier: { $0.timeoutInterval = max(limits.header, limits.body) }
                )
                .validate()
                timeout.observe(request)
                request.responseStream { [weak self, weak request] in
                    guard let self = self, self.activeDiagnostics === diagnostics else {
                        // 旧接続の通知を破棄するときも、残った監視を明示的に解除する。
                        timeout.stop()
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    if let retries = request?.retryCount, retries != parsedRetryCount {
                        // 再取得はフレームの先頭から始まるため、前の試行の未完フレームを混ぜない。
                        unread = nil
                        parsedRetryCount = retries
                    }
                    switch $0.event {
                    case let .stream(result):
                        // log.debug("📦 stream (\(messageType))")
                        switch result {
                        case let .success(data):
                            timeout.receivedData(data)
                            if diagnostics.record(activity) {
                                diagnostics.emit("\(label): この接続で初めてデータを受信")
                            }
                            receivedBytes += data.count
                            log.debug("data from stream: \(data)")
                            let decoded = self.decode(unread: unread, data: data, messageType: T.self)
                            unread = decoded.truncated
                            log.debug("unread: (\(unread?.count ?? 0)).")
                            if (unread?.count ?? 0) > 10_240 {
                                log.error("unread data too large (\(unread?.count ?? 0)), drop.")
                                unread = nil
                            }
                            log.debug("unread: \(String(describing: unread))")
                            for message in decoded.messages {
                                continuation.yield(message)
                            }
                        case .failure(let error):
                            log.error(error)
                            diagnostics.emit("\(label): データ処理失敗 \(ConnectionDiagnostics.errorSummary(error))")
                            continuation.finish(throwing: error)
                        }
                    case .complete(let completion):
                        timeout.stop()
                        // chunk 間の未完フレームは正常だが、EOF まで残れば途中切断として上位へ伝える。
                        // EOF をすべて放送終了扱いすると、配信中なのに Live closed となる。
                        let error: Error? = completion.error ?? ((unread?.isEmpty == false) ? NdgrStreamError.truncatedFrame : nil)
                        if let renewal = retrier.takeConnectionRenewal(request, error: error) {
                            continuation.finish(throwing: renewal)
                            return
                        }
                        retrier.reportCompletedAttempt(request, error: error, receivedBytes: receivedBytes)
                        session.throttle.recordResponse(success: error == nil)
                        // 失敗を上位へ伝え、正常な EOF と区別する。
                        diagnostics.reportStreamCompletion(completion, request: label,
                                                           receivedBytes: receivedBytes, unreadBytes: unread?.count ?? 0)
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { @Sendable _ in
                    request.cancel()
                }
                // 高速な応答でもヘッダー通知を取りこぼさないよう、監視を設置してから開始する。
                request.resume()
            }
        })
    }

    // swiftlint:enable function_body_length

    // #2. stream data を protobuf messages として parse する。
    // data がちぎれていた場合は、truncated として返して次回 parse に回す。
    struct DecodeResult<T> {
        let messages: [T]
        let truncated: Data?
    }

    func decode<T: SwiftProtobuf.Message>(
        unread: Data?,
        data: Data,
        messageType: T.Type
    ) -> DecodeResult<T> {
        let splitted = splitLengthDelimitedData(
            unread: unread,
            data: data
        )

        var messages: [T] = []
        for chunk in splitted.chunks {
            guard let message = try? T.init(serializedBytes: chunk) else { continue }
            messages.append(message)
        }

        return DecodeResult(
            messages: messages,
            truncated: splitted.truncated
        )
    }

    // #3. 生の data を length delimited なものとして parse して chunk data を返す。
    struct SplitLengthDelimitedDataResult {
        let chunks: [Data]
        let truncated: Data?
    }

    func splitLengthDelimitedData(unread: Data?, data: Data) -> SplitLengthDelimitedDataResult {
        let concatenated = {
            guard let unread = unread else { return data }
            return unread + data
        }()

        var chunks: [Data] = []
        var truncated: Data?
        var offset = 0
        while offset < concatenated.count {
            do {
                let varint = try decodeVarint(concatenated, offset: offset)
                let length = varint.value
                // 予防保守として、varint の値があまりに大きな場合はなにかおかしいので、ここで処理をやめる。
                if length > 102_400 {
                    log.error("varint value too large (\(length)), drop.")
                    break
                }
                let remainingDataLength = concatenated.count - offset - varint.bytesRead
                if remainingDataLength < length {
                    // data がちぎれているので、次回 parse に持ち越す。
                    truncated = concatenated.subdata(in: offset..<concatenated.count)
                    break
                }
                offset += varint.bytesRead
                let delimitedData = concatenated.subdata(in: offset..<(offset + length))
                offset += delimitedData.count
                chunks.append(delimitedData)
            } catch DecodeVarintError.truncated {
                log.warning("detected truncated data, reuse.")
                truncated = concatenated.subdata(in: offset..<concatenated.count)
                log.debug("reuse next decode: \(String(describing: truncated))")
                break
            } catch DecodeVarintError.malformedProtobuf {
                log.error("detected malformed data, skip")
                break
            } catch {
                log.error("detected decode error: \(error)")
                break
            }
        }
        let result = SplitLengthDelimitedDataResult(
            chunks: chunks,
            truncated: truncated
        )
        log.debug(result)
        return result
    }

    // #4. length delimited data の varint type を parse する。
    struct VarintResult {
        let value: Int
        let bytesRead: Int
    }

    enum DecodeVarintError: Swift.Error {
        case malformedProtobuf
        case noBytesAvailable
        case truncated
    }

    func decodeVarint(_ data: Data, offset fromOffset: Int) throws -> VarintResult {
        var offset = fromOffset
        var bytesRead = 0

        var value: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard offset < data.count else {
                throw shift == 0
                ? DecodeVarintError.noBytesAvailable
                : DecodeVarintError.truncated
            }
            let c = data[offset]
            bytesRead += 1
            value |= UInt64(c & 0x7f) << shift
            if c & 0x80 == 0 {
                break
            }
            shift += 7
            if shift > 63 {
                throw DecodeVarintError.malformedProtobuf
            }
            offset += 1
        }
        return VarintResult(
            value: Int(value),
            bytesRead: bytesRead
        )
    }
}

@MainActor
private final class ChatHistory {
    var metaIds = Set<String>()
    var isFetching = true
    var didFinish = false
    private(set) var totalCount = 0
    private(set) var chats: [Chat] = []
    var isEmpty: Bool { chats.isEmpty }

    func append(_ chat: Chat) {
        chats.append(chat)
        totalCount += 1
    }

    func removeAll() {
        chats.removeAll()
        metaIds.removeAll()
    }
}

private extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }
}

private extension URL {
    // https://stackoverflow.com/a/50990443
    func appending(_ queryItem: String, value: String?) -> URL {
        guard var urlComponents = URLComponents(string: absoluteString) else { return absoluteURL }
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        let queryItem = URLQueryItem(name: queryItem, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else {
            log.error("failed to make url.")
            return self
        }
        return url
    }
}

private extension Dwango_Nicolive_Chat_Data_NicoliveMessage {
    func toChat() -> Chat? {
        guard let data = data else { return nil }
        switch data {
        case .chat(let chat):
            return chat.toChat()
        case .simpleNotification(let notification):
            return notification.toChat()
        case .gift(let gift):
            return gift.toChat()
        case .nicoad(let nicoad):
            return nicoad.toChat()
        case .gameUpdate:
            return nil
        case .tagUpdated:
            return nil
        case .moderatorUpdated:
            return nil
        case .ssngUpdated:
            return nil
        case .overflowedChat(let chat):
            return chat.toChat(isOverflowed: true)
        }
    }
}

private extension Dwango_Nicolive_Chat_Data_Chat {
    func toChat(isOverflowed: Bool = false) -> Chat {
        return Chat(
            roomPosition: isOverflowed ? .storeA : .arena,
            no: Int(no),
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: hasRawUserID ? String(rawUserID) : hashedUserID,
            comment: content,
            premium: {
                switch accountStatus {
                case .standard:
                    return .ippan
                case .premium:
                    return .premium
                case .UNRECOGNIZED:
                    return .ippan
                }
            }(),
            chatType: .comment
        )
    }
}

private extension Dwango_Nicolive_Chat_Data_NicoliveState {
    func isDisconnect() -> Bool {
        guard hasProgramStatus else { return false }
        switch programStatus.state {
        case .ended:
            return true
        case .unknown, .UNRECOGNIZED:
            return false
        }
    }

    func toChat() -> Chat? {
        if hasMarquee {
            return marquee.toChat()
        }
        // TODO: その他の state を処理する。
        return nil
    }
}

private extension Dwango_Nicolive_Chat_Data_Marquee {
    func toChat() -> Chat {
        return Chat(
            roomPosition: .arena,
            no: 0,
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: "",
            comment: hasDisplay && display.hasOperatorComment ? display.operatorComment.content : "",
            premium: .caster,
            chatType: .other
        )
    }
}

private extension Dwango_Nicolive_Chat_Data_SimpleNotification {
    func toChat() -> Chat? {
        guard let message = message else { return nil }
        let text = {
            switch message {
            case .ichiba(let text):
                return "🎮 \(text)"
            case .quote(let text):
                return "⛴ \(text)"
            case .emotion(let text):
                return "💬 \(text)"
            case .cruise(let text):
                return "⚓️ \(text)"
            case .programExtended(let text):
                return "ℹ️ \(text)"
            case .rankingIn(let text):
                return "📈 \(text)"
            case .rankingUpdated(let text):
                return "📈 \(text)"
            case .visited(let text):
                return "👥 \(text)"
            }
        }()
        return Chat(
            roomPosition: .arena,
            no: 0,
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: "-",
            comment: text,
            premium: .system,
            chatType: .other
        )
    }
}

// TODO: 想像で実装しただけなので、機能が実際に使えるようになったら動作確認する。
private let giftImageUrl = "https://secure-dcdn.cdn.nimg.jp/nicoad/res/nage/thumbnail/%@.png"

private extension Dwango_Nicolive_Chat_Data_Gift {
    func toChat() -> Chat? {
        let imageUrlString = String(format: giftImageUrl, itemID)
        guard let imageUrl = URL(string: imageUrlString) else { return nil }
        return Chat(
            roomPosition: .arena,
            no: 0,
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: "-",
            // 【ギフト貢献2位】カクれんぼさんがギフト「出前館福引チケット(並)（5000pt）」を贈りました
            comment: "🎁 \(advertiserName)さんがギフト「\(itemName)（\(String(point))pt）」を贈りました",
            premium: .system,
            chatType: .gift(imageUrl: imageUrl)
        )
    }
}

// TODO: 想像で実装しただけなので、機能が実際に使えるようになったら動作確認する。
private extension Dwango_Nicolive_Chat_Data_Nicoad {
    func toChat() -> Chat? {
        guard let versions = versions else { return nil }
        let text = {
            switch versions {
            case .v0(let v0):
                return v0.hasLatest && v0.latest.hasMessage ? v0.latest.message : "-"
            case .v1(let v1):
                return v1.message
            }
        }()
        return Chat(
            roomPosition: .arena,
            no: 0,
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: "-",
            comment: "📣 \(text)",
            premium: .system,
            chatType: .nicoad
        )
    }
}

// Segment の失敗を View の受信待ちにも伝える。状態は main actor 上でのみ操作する。
@MainActor
private final class ViewIteration {
    var stop: ((Error?) -> Void)?
    private(set) var failure: Error?
    private(set) var programEnded = false
    var pendingSegments = 0
    var failedSegments = 0
    private var endDeadline: DispatchWorkItem?

    func endProgram(timeout: TimeInterval, diagnostics: ConnectionDiagnostics, session: NdgrTransport) {
        // 終了状態を受信した Segment と他の Segment は並行する。即時全キャンセルによる末尾欠落を
        // 減らす一方、閉じないストリームを永遠に待たないよう、開始済みの取得だけを期限付きで待つ。
        guard !programEnded else { return }
        programEnded = true
        session.stopNewRequests()
        diagnostics.emit("NDGR Segment: サーバーから放送終了状態を受信")
        stop?(nil)
        // 呼び出し元の終了通知Segmentは戻った後のdeferで減るため、待機対象から先に除く。
        diagnostics.emit("NDGR終了待ち開始: 残りSegment=\(pendingSegments - 1), 上限=\(timeout)秒, 新規取得・復旧は行わない")
        let deadline = DispatchWorkItem { [weak self] in
            guard let self = self, self.pendingSegments > 0 else { return }
            diagnostics.emit("NDGR終了待ち上限: 未完了Segment=\(self.pendingSegments), HTTPをキャンセルして終了")
            session.cancelAllRequests()
        }
        endDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: deadline)
    }

    func cancelEndDeadline() {
        endDeadline?.cancel()
        endDeadline = nil
    }

    func fail(_ error: Error) {
        guard failure == nil else { return }
        failure = error
        stop?(error)
    }
}
