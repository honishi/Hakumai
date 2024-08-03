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
    private let g_play_start = Int(Date().timeIntervalSince1970 * 1_000)
    private let g_play_from = Int(Date().timeIntervalSince1970 * 1_000)
    private let g_play_rate = 1.0

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
        _connect(viewUri: viewUri)
    }
}

// MARK: - Private Functions
private extension NdgrClient {
    func _connect(viewUri: URL) {
        Task {
            await _forward_playlist(uri: viewUri, from: Int(Date().timeIntervalSince1970))
        }
    }

    func _forward_playlist(uri: URL, from: Int?) async {
        var next: Int? = from
        while next != nil {
            let url = uri.appending(
                "at",
                value: {
                    guard let next = next else { return "now" }
                    return String(describing: next)
                }()
            )
            log.debug("🪞 view")
            let entries = _retrieve(
                uri: url,
                messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self
            )
            for await entry in entries {
                // log.info(entry)
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
                    // await _sleep_until(timestamp: segment.from, prefetch: 10_000)
                    guard let url = URL(string: segment.uri) else {
                        log.error("failed to create url: \(segment.uri)")
                        continue
                    }
                    Task {
                        await _pull_messages(uri: url)
                    }
                case .next(let _next):
                    log.info("⏭️ next -> \(_next.at)")
                    next = Int(_next.at)
                }
            }
        }
        log.info("done: _forward_playlist")
    }

    func _pull_messages(uri: URL) async {
        let messages = _retrieve(
            uri: uri,
            messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage.self
        )
        for await message in messages {
            // await _sleep_until(timestamp: message.meta.at)
            guard let payload = message.payload else { continue }
            switch payload {
            case .message(let message):
                let chat = Chat(
                    roomPosition: .arena,
                    no: Int(message.chat.no),
                    date: Date(),
                    dateUsec: 10,
                    mail: [],
                    userId: message.chat.hashedUserID,
                    comment: message.chat.content,
                    premium: .ippan
                )
                delegate?.ndgrClientDidReceiveChat(self, chat: chat)
            case .state:
                break
            case .signal:
                break
            }
        }
        log.info("done: _pull_messages")
    }

    func _retrieve<T: SwiftProtobuf.Message>(
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
            // TODO: handleResponseStream()
            .responseStream {
                switch $0.event {
                case let .stream(result):
                    log.debug("📦 stream (\(messageType))")
                    switch result {
                    case let .success(data):
                        let stream = InputStream(data: data)
                        stream.open()
                        defer { stream.close() }

                        while stream.hasBytesAvailable {
                            do {
                                let parsed = try BinaryDelimited.parse(
                                    messageType: messageType,
                                    from: stream
                                )
                                continuation.yield(parsed)
                            } catch {
                                if stream.hasBytesAvailable {
                                    log.error("メッセージの解析中にエラーが発生しました: \(error)")
                                } else {
                                    // ストリームの終わりに達した場合は正常
                                    break
                                }
                            }
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

    // timestamp(protobuf)のprefetchミリ秒前までsleep
    func _sleep_until(timestamp: Google_Protobuf_Timestamp, prefetch: Int = 0) async {
        let until = _unix_ts(timestamp: timestamp)
        let now = Int(Date().timeIntervalSince1970 * 1_000)

        // 現在の再生位置
        let play_at = _play_pos(at: now)
        // 遅延してたら即時返す
        if until <= play_at { return }
        // 因果律の壁(再生時刻は現在時刻を追い越せない) until >= ab >= play_at
        let ab = max(
            play_at,
            min(
                until,
                // Int(Double(now - play_at) * g_play_rate / (g_play_rate - 1)) + play_at
                play_at
            )
        )
        // abまでのdelay
        let delay_a = Int(Double(ab - play_at) / g_play_rate)
        // ab以降のdelay
        let delay_b = Int(Double(until - ab) / min(1, g_play_rate))

        await _sleep_ms(ms: delay_a + delay_b - prefetch)
    }

    // at: milliseconds
    func _play_pos(at: Int) -> Int {
        let elapsed = Double(at - g_play_start)
        return min(Int(Double(g_play_from) + elapsed * g_play_rate), at)
    }

    // unix ts (seconds) -> milliseconds
    func _unix_ts(timestamp: Google_Protobuf_Timestamp) -> Int {
        return Int(timestamp.seconds * 1_000) + Int(timestamp.nanos / 1_000_000)
    }

    // ms: milliseconds
    func _sleep_ms(ms: Int) async {
        // log.debug("_sleep_ms: \(ms)")
        if ms <= 0 { return }
        // TODO: extension toNanosecondsFromMilliseconds
        try? await Task.sleep(nanoseconds: UInt64(ms * 1_000_000))
    }
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }
}

extension URL {
    // https://stackoverflow.com/a/50990443
    func appending(_ queryItem: String, value: String?) -> URL {
        guard var urlComponents = URLComponents(string: absoluteString) else { return absoluteURL }
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        let queryItem = URLQueryItem(name: queryItem, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        guard let url = urlComponents.url else { return self }
        return url
    }
}
