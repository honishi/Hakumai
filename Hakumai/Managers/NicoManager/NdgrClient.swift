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
    func connect(viewUri: URL) {
        Task {
            await forward_playlist(uri: viewUri, from: Int(Date().timeIntervalSince1970))
            self.delegate?.ndgrClientDidDisconnect(self)
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
    func forward_playlist(uri: URL, from: Int?) async {
        var next: Int? = from
        while next != nil {
            log.debug("🪞 view")
            let entries = retrieve(
                uri: uri.appending("at", value: next.toAtParameter()),
                messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self
            )
            next = nil
            for await entry in entries {
                guard let entry = entry.entry else {
                    log.error("entry.entry is nil")
                    continue
                }
                switch entry {
                case .backward:
                    log.info("⏮️ backward")
                case .previous:
                    log.info("⏮️ previous")
                case .segment(let segment):
                    log.info("📩 segment")
                    guard let url = URL(string: segment.uri) else {
                        log.error("failed to create url: \(segment.uri)")
                        continue
                    }
                    Task {
                        await pull_messages(uri: url)
                    }
                case .next(let _next):
                    log.info("⏭️ next -> \(_next.at)")
                    next = Int(_next.at)
                }
            }
        }
        log.info("done: _forward_playlist")
    }

    func pull_messages(uri: URL) async {
        let messages = retrieve(
            uri: uri,
            messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage.self
        )
        for await message in messages {
            guard let payload = message.payload else { continue }
            switch payload {
            case .message(let message):
                delegate?.ndgrClientDidReceiveChat(self, chat: message.toChat())
            case .state:
                break
            case .signal:
                break
            }
        }
        log.info("done: _pull_messages")
    }

    func retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type
    ) -> AsyncStream<T> {
        // log.debug("\(uri.absoluteString)")
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
                        for message in self.decode(data: data, messageType: T.self) {
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

    func decode<T: SwiftProtobuf.Message>(data: Data, messageType: T.Type) -> [T] {
        let stream = InputStream(data: data)
        stream.open()
        defer { stream.close() }

        var messages: [T] = []
        while stream.hasBytesAvailable {
            do {
                let parsed = try BinaryDelimited.parse(
                    messageType: messageType,
                    from: stream
                )
                messages.append(parsed)
            } catch {
                if stream.hasBytesAvailable {
                    log.error("メッセージの解析中にエラーが発生しました: \(error)")
                } else {
                    // ストリームの終わりに達した場合は正常
                    break
                }
            }
        }
        return messages
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
    func toChat() -> Chat {
        return Chat(
            roomPosition: .arena,
            no: Int(chat.no),
            date: Date(),
            dateUsec: 0,
            mail: [],
            userId: chat.hasRawUserID ? String(chat.rawUserID) : chat.hashedUserID,
            comment: chat.content,
            premium: {
                switch chat.accountStatus {
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
