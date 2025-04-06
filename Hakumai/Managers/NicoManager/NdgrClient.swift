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
    private let session: Session
    private var receivedMessageMetaIds = Set<String>()
    private let metaIdCheckLock = NSLock()

    init(delegate: NdgrClientDelegate? = nil) {
        self.delegate = delegate
        session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(commonUserAgentValue))
            let interceptor = Interceptor(retriers: [NdgrRequestRetrier()])
            return Session(configuration: configuration, interceptor: interceptor)
        }()
    }
}

// MARK: - Public Functions
extension NdgrClient {
    func connect(viewUri: URL, beginTime: Date) {
        Task {
            // TODO: 厳密には ndgrClientDidConnect はこの位置ではない。
            delegate?.ndgrClientDidConnect(self)
            await forwardPlaylist(uri: viewUri, from: Int(beginTime.timeIntervalSince1970))
            delegate?.ndgrClientDidDisconnect(self)
        }
    }

    func disconnect() {
        session.cancelAllRequests { [weak self] in
            guard let self = self else { return }
            self.delegate?.ndgrClientDidDisconnect(self)
        }
    }
}

// MARK: - Private Functions
private extension NdgrClient {
    // swiftlint:disable function_body_length
    func forwardPlaylist(uri: URL, from: Int?) async {
        var next: Int? = from

        var segmentCount = 0
        let chatHistory = ChatHistory()
        // 現在時刻より少し前 (1segment = 16sec * n) で history chat としての読み込みをやめる
        let latestHistoryTime = Int(Date().timeIntervalSince1970) - 16 * 4

        while next != nil {
            let current = next ?? 0
            log.debug("🪞 view: \(current)")
            let entries = retrieve(
                uri: uri.appending("at", value: next.toAtParameter()),
                messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self
            )
            chatHistory.isFetching = current < latestHistoryTime
            if !chatHistory.isFetching {
                emitChatHistoryIfExists(chatHistory: chatHistory)
            }
            next = nil
            for await entry in entries {
                guard let entry = entry.entry else {
                    log.error("entry.entry is nil")
                    continue
                }
                switch entry {
                case .backward:
                    // log.info("⏮️ backward: \(current)")
                    continue
                case .previous:
                    // log.info("⏮️ previous: \(current)")
                    continue
                case .segment(let segment):
                    log.info("📩 segment: \(current)")
                    segmentCount += 1
                    guard let url = URL(string: segment.uri) else {
                        log.error("failed to create url: \(segment.uri)")
                        continue
                    }
                    let _segmentCount = segmentCount
                    Task {
                        await pullMessages(uri: url, chatHistory: chatHistory)
                        if chatHistory.isFetching {
                            delegate?.ndgrClientReceivingChatHistory(
                                self,
                                requestCount: _segmentCount,
                                totalChatCount: chatHistory.chats.count
                            )
                        }
                    }
                case .next(let _next):
                    log.info("⏭️ next: \(current) -> \(_next.at)")
                    next = Int(_next.at)
                }
            }
        }
        emitChatHistoryIfExists(chatHistory: chatHistory)
        log.debug("done: \(next ?? 0)")
    }
    // swiftlint:enable function_body_length

    func emitChatHistoryIfExists(chatHistory: ChatHistory) {
        guard !chatHistory.isEmpty else { return }
        delegate?.ndgrClientDidReceiveChatHistory(self, chats: chatHistory.chats)
        chatHistory.removeAll()
    }

    // swiftlint:disable cyclomatic_complexity
    func pullMessages(uri: URL, chatHistory: ChatHistory) async {
        let onReceiveChat = { [weak self] (chat: Chat) in
            // TODO: まだ chat 消失のケースがある。
            log.debug(chat)
            if chatHistory.isFetching {
                chatHistory.append(chat)
                return
            }
            guard let self = self else { return }
            delegate?.ndgrClientDidReceiveChat(self, chat: chat)
        }
        var detectedDisconnection = false
        let messages = retrieve(
            uri: uri,
            messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage.self
        )
        for await message in messages {
            if checkIfMessageIsReceived(metaId: message.meta.id) {
                continue
            }
            guard let payload = message.payload else { continue }
            switch payload {
            case .message(let message):
                guard let chat = message.toChat() else {
                    log.warning("need to handle this message. (\(String(describing: message.data)))")
                    continue
                }
                onReceiveChat(chat)
            case .state(let state):
                if state.isDisconnect() {
                    detectedDisconnection = true
                    continue
                }
                guard let chat = state.toChat() else {
                    log.warning("need to handle this state. (\(String(describing: state)))")
                    continue
                }
                onReceiveChat(chat)
            case .signal(let signal):
                log.debug("flushed: (\(signal == .flushed))")
                continue
            }
        }
        if detectedDisconnection {
            disconnect()
        }
        log.debug("done")
    }
    // swiftlint:enable cyclomatic_complexity

    func checkIfMessageIsReceived(metaId: String) -> Bool {
        guard !metaId.isEmpty else {
            return false
        }
        metaIdCheckLock.lock()
        defer { metaIdCheckLock.unlock() }
        let alreadyReceived = receivedMessageMetaIds.contains(metaId)
        // log.info("is received meta-id: \(alreadyReceived) (\(metaId))")
        receivedMessageMetaIds.insert(metaId)
        return alreadyReceived
    }
}

// Low layer for chunked network I/O.
private extension NdgrClient {
    // #1. 指定された uri を stream として listen しつつ、
    // 逐一 protobuf message として parse したものを stream として返す。
    func retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type
    ) -> AsyncStream<T> {
        // log.debug("\(uri.absoluteString)")
        var unread: Data?

        return AsyncStream { continuation in
            let request = session.streamRequest(
                uri,
                method: .get
            )
            .validate()
            .responseStream { [weak self] in
                guard let self = self else { return }
                switch $0.event {
                case let .stream(result):
                    // log.debug("📦 stream (\(messageType))")
                    switch result {
                    case let .success(data):
                        log.debug("data from stream: \(data)")
                        let decoded = self.decode(
                            unread: unread,
                            data: data,
                            messageType: T.self
                        )
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
                    }
                case .complete:
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable _ in
                request.cancel()
            }
        }
    }

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

private final class ChatHistory: @unchecked Sendable {
    private var _isFetching = true
    private var _chats: [Chat] = []
    private let lock = NSLock()

    var isFetching: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isFetching
        }
        set(value) {
            lock.lock()
            defer { lock.unlock() }
            _isFetching = value
        }
    }

    init() {}

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _chats.isEmpty
    }

    var chats: [Chat] {
        lock.lock()
        defer { lock.unlock() }
        return _chats
    }

    func append(_ chat: Chat) {
        lock.lock()
        defer { lock.unlock() }
        _chats.append(chat)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        _chats.removeAll()
    }
}

private extension Optional<Int> {
    func toAtParameter() -> String {
        switch self {
        case .none:
            return "now"
        case .some(let value):
            return String(describing: value)
        }
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

final class NdgrRequestRetrier: RequestRetrier {
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        log.debug("RequestRetrier > request: \(request) error: \(error)")
        guard
            let afError = error.asAFError,
            case .sessionTaskFailed(let underlyingError) = afError,
            // Code=-1005 "The network connection was lost."
            (underlyingError as NSError).code == -1005
        else {
            log.debug("RequestRetrier > not retry")
            completion(.doNotRetry)
            return
        }
        log.debug("RequestRetrier > perform retry")
        // すでに1回リトライしていたら再試行しない、そうでなければリトライする
        completion(request.retryCount >= 1 ? .doNotRetry : .retry)
    }
}
