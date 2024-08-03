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
                value: { // () -> String in
                    guard let next = next else { return "now" }
                    return String(describing: next)
                }()
            )
            let entries = _retrieve(
                uri: url,
                messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self
            )
            for await entry in entries {
                log.info(entry)
                guard let entry = entry.entry else { continue }
                switch entry {
                case .backward(let backward):
                    break
                case .previous(let previous):
                    break
                case .segment(let segment):
                    guard let url = URL(string: segment.uri) else { continue }
                    await _pull_messages(uri: url)
                case .next(let _next):
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
            log.info(message)
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
            case .state(let state):
                break
            case .signal(let signal):
                break
            }
        }
        log.info("done: _pull_messages")
    }

    func _retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type
    ) -> AsyncStream<T> {
        AsyncStream { continuation in
            session.streamRequest(
                uri,
                method: .get
            )
            .validate()
            .responseStream {
                switch $0.event {
                case let .stream(result):
                    switch result {
                    case let .success(data):
                        // log.debug(data)
                        // log.debug(data.hexEncodedString())
                        do {
                            let stream = InputStream(data: data)
                            stream.open()
                            let parsed = try BinaryDelimited.parse(
                                messageType: messageType,
                                from: stream,
                                partial: true
                            )
                            // log.debug(parsed)
                            stream.close()
                            // onStream(parsed)
                            continuation.yield(parsed)
                        } catch {
                            log.error(error)
                            log.error(error.localizedDescription)
                        }
                    }
                case .complete:
                    // print(completion)
                    // log.debug("done.")
                    // onComplete()
                    continuation.finish()
                }
            }
        }
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
