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
    private var streamSession: Session?
    private var streamTask: Task<Void, Never>?
    private var activeDiagnostics: ConnectionDiagnostics?
    private var receivedMessageMetaIds = Set<String>()
    private var resumeAt: Int?
    private var connected = false
    private var duplicateCount = 0

    init(delegate: NdgrClientDelegate? = nil, configuration: URLSessionConfiguration = .af.default) {
        self.delegate = delegate
        self.configuration = configuration
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
            receivedMessageMetaIds.removeAll()
            resumeAt = Int(beginTime.timeIntervalSince1970)
        }
        let session = Session(configuration: configuration)
        streamSession = session
        activeDiagnostics = diagnostics
        connected = false
        duplicateCount = 0
        diagnostics.emit("NDGR開始 (受信待ちタイムアウト=\(configuration.timeoutIntervalForRequest)秒), 再開=\(resuming), at=\(resumeAt ?? Int(beginTime.timeIntervalSince1970))")
        streamTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let reason: NdgrTermination
            do {
                try await self.forwardPlaylist(uri: viewUri, from: self.resumeAt ?? Int(beginTime.timeIntervalSince1970),
                                               diagnostics: diagnostics, session: session)
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
    // swiftlint:disable:next cyclomatic_complexity
    func forwardPlaylist(uri: URL, from: Int, diagnostics: ConnectionDiagnostics, session: Session) async throws {
        var next: Int? = from
        var segmentCount = 0
        let chatHistory = ChatHistory()
        defer { emitChatHistoryIfExists(chatHistory: chatHistory, diagnostics: diagnostics) }
        let latestHistoryTime = Int(Date().timeIntervalSince1970) - 16 * 4

        while let current = next {
            try Task.checkCancellation()
            chatHistory.isFetching = current < latestHistoryTime
            if !chatHistory.isFetching {
                emitChatHistoryIfExists(chatHistory: chatHistory, diagnostics: diagnostics)
            }
            next = nil
            // Segment の完了を待ってから再開位置を進め、取得途中のコメントを飛ばさない。
            try await withThrowingTaskGroup(of: Void.self) { group in
                var activeSegments = 0
                let entries = retrieve(uri: uri.appending("at", value: String(current)),
                                       messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self,
                                       activity: .view, diagnostics: diagnostics, session: session)
                for try await entry in entries {
                    try Task.checkCancellation()
                    guard let entry = entry.entry else { continue }
                    switch entry {
                    case .backward, .previous: continue
                    case .segment(let segment):
                        guard let url = URL(string: segment.uri) else { throw NdgrStreamError.invalidSegmentURL }
                        if activeSegments >= 8 {
                            try await group.next()
                            activeSegments -= 1
                        }
                        segmentCount += 1
                        activeSegments += 1
                        group.addTask {
                            try await self.pullMessages(uri: url, chatHistory: chatHistory,
                                                        diagnostics: diagnostics, session: session)
                        }
                    case .next(let marker): next = Int(marker.at)
                    }
                }
                try await group.waitForAll()
            }
            try Task.checkCancellation()
            if chatHistory.isFetching {
                delegate?.ndgrClientReceivingChatHistory(self, requestCount: segmentCount,
                                                         totalChatCount: chatHistory.chats.count, diagnostics: diagnostics)
            }
            // 再開位置より前の履歴は通知済みにする。途中停止で未通知の履歴を飛ばさないため。
            emitChatHistoryIfExists(chatHistory: chatHistory, diagnostics: diagnostics)
            try Task.checkCancellation()
            if let next = next { resumeAt = next }
        }
        diagnostics.emit("NDGR Viewループ終了: 次の取得位置なし (segments=\(segmentCount))")
    }

    @MainActor
    func emitChatHistoryIfExists(chatHistory: ChatHistory, diagnostics: ConnectionDiagnostics) {
        guard activeDiagnostics === diagnostics, !chatHistory.isEmpty else { return }
        receivedMessageMetaIds.formUnion(chatHistory.metaIds)
        delegate?.ndgrClientDidReceiveChatHistory(self, chats: chatHistory.chats, diagnostics: diagnostics)
        chatHistory.removeAll()
    }

    @MainActor
    func pullMessages(uri: URL, chatHistory: ChatHistory, diagnostics: ConnectionDiagnostics, session: Session) async throws {
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
                    // 終了通知を見た時点で他の受信も止め、HTTP EOF 待ちで終了を遅らせない。
                    diagnostics.emit("NDGR Segment: サーバーから放送終了状態を受信")
                    emitChatHistoryIfExists(chatHistory: chatHistory, diagnostics: diagnostics)
                    disconnect()
                    delegate?.ndgrClientDidDisconnect(self, diagnostics: diagnostics, reason: .programEnded)
                    throw NdgrStreamError.programEnded
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
    func retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type,
        activity: ConnectionDiagnostics.Activity,
        diagnostics: ConnectionDiagnostics,
        session: Session
    ) -> AsyncThrowingStream<T, Error> {
        // log.debug("\(uri.absoluteString)")
        var unread: Data?
        let requestID = diagnostics.nextRequestID()
        let label = "\(activity.rawValue) HTTP#\(requestID)"
        var receivedBytes = 0
        var parsedRetryCount = 0
        let retrier = NdgrRequestRetrier { message in
            diagnostics.emit("\(label): \(message)")
        }

        return AsyncThrowingStream { continuation in
            let request = session.streamRequest(
                uri,
                method: .get,
                interceptor: Interceptor(retriers: [retrier])
            )
            .validate()
            request.responseStream { [weak self, weak request] in
                guard let self = self, self.activeDiagnostics === diagnostics else {
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
                    if completion.error == nil && parsedRetryCount > 0 {
                        diagnostics.emit("\(label): HTTP再試行で回復, 試行済み=\(parsedRetryCount), 受信=\(receivedBytes)bytes")
                    }
                    // 失敗を上位へ伝え、正常な EOF と区別する。
                    diagnostics.reportStreamCompletion(completion, request: label,
                                                       receivedBytes: receivedBytes, unreadBytes: unread?.count ?? 0)
                    continuation.finish(throwing: completion.error ?? ((unread?.isEmpty == false) ? NdgrStreamError.truncatedFrame : nil))
                }
            }
            continuation.onTermination = { @Sendable _ in
                request.cancel()
            }
        }
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
    private(set) var chats: [Chat] = []
    var isEmpty: Bool { chats.isEmpty }

    func append(_ chat: Chat) { chats.append(chat) }

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

// reportはロックで保護された診断情報を更新し、UI側は既存のmain queue経由で表示する。
final class NdgrRequestRetrier: RequestRetrier, @unchecked Sendable {
    private let report: (String) -> Void

    init(report: @escaping (String) -> Void) {
        self.report = report
    }

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        log.debug("RequestRetrier > error: \(ConnectionDiagnostics.errorSummary(error))")
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
        let action = request.retryCount >= 1 ? "再試行上限に到達" : "1回目の再試行を実行"
        report("\(action): \(ConnectionDiagnostics.errorSummary(error))")
        // すでに1回リトライしていたら再試行しない、そうでなければリトライする
        completion(request.retryCount >= 1 ? .doNotRetry : .retry)
    }
}
