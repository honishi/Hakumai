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

    init(delegate: NdgrClientDelegate? = nil) {
        self.delegate = delegate
        session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(commonUserAgentValue))
            return Session(configuration: configuration)
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
    // swiftlint:disable function_body_length cyclomatic_complexity
    func forwardPlaylist(uri: URL, from: Int?) async {
        var next: Int? = from

        var segmentCount = 0
        let historyChat = HistoryChat()
        // 現在時刻より少し前 (1segment = 16sec * 2) で history chat としての読み込みをやめる
        let latestHistoryTime = Int(Date().timeIntervalSince1970) - 16 * 2

        while next != nil {
            log.debug("🪞 view")
            let entries = retrieve(
                uri: uri.appending("at", value: next.toAtParameter()),
                messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self
            )
            let isFetchingHistory = (next ?? 0) < latestHistoryTime
            if !isFetchingHistory {
                emitChatHistoryIfNeeded(historyChat: historyChat)
            }
            next = nil
            for await entry in entries {
                guard let entry = entry.entry else {
                    log.error("entry.entry is nil")
                    continue
                }
                switch entry {
                case .backward:
                    // log.info("⏮️ backward")
                    continue
                case .previous:
                    // log.info("⏮️ previous")
                    continue
                case .segment(let segment):
                    log.info("📩 segment")
                    segmentCount += 1
                    guard let url = URL(string: segment.uri) else {
                        log.error("failed to create url: \(segment.uri)")
                        continue
                    }
                    let _segmentCount = segmentCount
                    Task {
                        await pullMessages(
                            uri: url,
                            historyChat: isFetchingHistory ? historyChat : nil
                        )
                        if isFetchingHistory {
                            delegate?.ndgrClientReceivingChatHistory(
                                self,
                                requestCount: _segmentCount,
                                totalChatCount: historyChat.chats.count
                            )
                        }
                    }
                case .next(let _next):
                    log.info("⏭️ next -> \(_next.at)")
                    next = Int(_next.at)
                }
            }
            if next == nil {
                emitChatHistoryIfNeeded(historyChat: historyChat)
            }
        }
        log.info("done: _forward_playlist")
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    func emitChatHistoryIfNeeded(historyChat: HistoryChat) {
        guard !historyChat.isEmpty else { return }
        delegate?.ndgrClientDidReceiveChatHistory(self, chats: historyChat.chats)
        historyChat.removeAll()
    }

    // swiftlint:disable cyclomatic_complexity
    func pullMessages(uri: URL, historyChat: HistoryChat?) async {
        let onReceiveChat = { [weak self] (chat: Chat) in
            if let historyChat = historyChat {
                historyChat.append(chat)
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
            case .signal:
                continue
            }
        }
        if detectedDisconnection {
            disconnect()
        }
        log.info("done: _pull_messages")
    }
    // swiftlint:enable cyclomatic_complexity

    func retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type
    ) -> AsyncStream<T> {
        // log.debug("\(uri.absoluteString)")
        var truncatedData: Data?

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
                        let decodeResult = self.decode(
                            truncatedData: truncatedData,
                            data: data,
                            messageType: T.self
                        )
                        truncatedData = decodeResult.truncatedData
                        if (truncatedData?.count ?? 0) > 2048 {
                            log.debug("XXX: truncatedData too large (\(truncatedData?.count ?? 0)), drop.")
                            truncatedData = nil
                        }
                        log.debug("XXX: truncatedData (\(truncatedData?.count ?? 0)).")
                        log.debug("XXX: \(truncatedData)")
                        for message in decodeResult.messages {
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

    struct DecodeResult<T> {
        let messages: [T]
        let truncatedData: Data?
    }

    func decode<T: SwiftProtobuf.Message>(
        truncatedData: Data?,
        data: Data,
        messageType: T.Type
    ) -> DecodeResult<T> {
        // log.debug("start decode: \(data.hexDump())")

        let splitResult = splitLengthDelimitedData(
            truncatedData: truncatedData,
            data: data
        )
        // truncatedData = splitResult.truncatedData
        // log.debug(splitResult)

        var messages: [T] = []
        for chunk in splitResult.chunks {
            guard let message = try? T.init(serializedBytes: chunk) else { continue }
            messages.append(message)
        }
        return DecodeResult(
            messages: messages,
            truncatedData: splitResult.truncatedData
        )
    }

    struct SplitLengthDelimitedDataResult {
        let chunks: [Data]
        let truncatedData: Data?
    }

    func splitLengthDelimitedData(truncatedData: Data?, data _data: Data) -> SplitLengthDelimitedDataResult {
        log.debug("===========")
        // TODO: truncated data が大きすぎる場合は、なにかおかしいので捨てる。

        // log.debug("truncatedData: \(truncatedData == nil ? nil : String(describing: truncatedData!)) data: \(_data)")
        let data = {
            guard let truncatedData = truncatedData else { return _data }
            return truncatedData + _data
        }()

        var chunks: [Data] = []
        var _truncatedData: Data?
        var offset = 0
        while offset < data.count {
            do {
                let varintResult = try decodeVarint(data, offset: offset)
                // log.debug(varintResult)
                let length = Int(varintResult.value)
                // TODO: length の現実的な範囲 (1k-2k?) を超えていたら処理を諦めてしまっていいかも。
                let remainingDataLength = data.count - offset - varintResult.bytesRead
                if remainingDataLength < length {
                    _truncatedData = data.subdata(in: offset..<data.count)
                    // log.debug("truncatedData: \(_truncatedData)")
                    break
                }
                offset += varintResult.bytesRead
                let delimitedData = data.subdata(in: offset..<(offset + length))
                offset += delimitedData.count
                chunks.append(delimitedData)
                // log.debug("data: \(delimitedData)")
            } catch BinaryDecodingError.truncated {
                log.error("Truncated Error, reuse.")
                _truncatedData = data.subdata(in: offset..<data.count)
                log.debug("truncatedData: \(_truncatedData)")
            } catch BinaryDecodingError.malformedProtobuf {
                log.error("Malformed Error, skip")
            } catch {
                log.error("Error: \(error)")
            }
        }
        let result = SplitLengthDelimitedDataResult(
            chunks: chunks,
            truncatedData: _truncatedData
        )
        log.debug(result)
        return result
    }

    struct VarintResult {
        let value: UInt64
        let bytesRead: Int
    }

    func decodeVarint(_ data: Data, offset fromOffset: Int) throws -> VarintResult {
        var offset = fromOffset
        var totalBytesRead = 0

        var value: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard offset < data.count else {
                if shift == 0 {
                    throw SwiftProtobufError.BinaryStreamDecoding.noBytesAvailable()
                }
                log.debug("guard let c = try nextByte() else")
                throw BinaryDelimited.Error.truncated
            }
            let c = data[offset]
            totalBytesRead += 1
            value |= UInt64(c & 0x7f) << shift
            if c & 0x80 == 0 {
                break
            }
            shift += 7
            if shift > 63 {
                log.debug("shift > 63")
                throw BinaryDecodingError.malformedProtobuf
            }
            offset += 1
        }
        return VarintResult(value: value, bytesRead: totalBytesRead)
    }
}

private final class HistoryChat: @unchecked Sendable {
    private var _chats: [Chat]
    private let lock = NSLock()

    init() {
        self._chats = []
    }

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
            }()
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
            premium: .caster
        )
    }
}

private extension Dwango_Nicolive_Chat_Data_SimpleNotification {
    func toChat() -> Chat? {
        guard let message = message else { return nil }
        let text = {
            switch message {
            case .ichiba(let text):
                return text
            case .quote(let text):
                return text
            case .emotion(let text):
                return text
            case .cruise(let text):
                return text
            case .programExtended(let text):
                return text
            case .rankingIn(let text):
                return text
            case .rankingUpdated(let text):
                return text
            case .visited(let text):
                return text
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
            premium: .system
        )
    }
}

// TODO: 想像で実装しただけなので、機能が実際に使えるようになったら動作確認する。
private extension Dwango_Nicolive_Chat_Data_Gift {
    func toChat() -> Chat? {
        return Chat(
            roomPosition: .arena,
            no: 0,
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: "-",
            comment: message,
            premium: .caster
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
            comment: text,
            premium: .caster
        )
    }
}
