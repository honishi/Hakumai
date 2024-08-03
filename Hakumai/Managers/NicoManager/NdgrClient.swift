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
        _forward_playlist(uri: viewUri, from: Int(Date().timeIntervalSince1970))
    }

    func _forward_playlist(uri: URL, from: Int?) {
        let url = uri.appending("at", value: from == nil ? "now" : "\(from!)")
        _retrieve(
            uri: url,
            messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedEntry.self,
            onStream: { [weak self] in
                // log.info($0)
                guard let entry = $0.entry else { return }
                switch entry {
                case .backward(let backward):
                    log.info(backward)
                case .previous(let previous):
                    log.info(previous)
                case .segment(let segment):
                    log.info(segment)
                    guard let url = URL(string: segment.uri) else { return }
                    self?._pull_messages(uri: url)
                case .next(let next):
                    log.info(next)
                    // TODO: calc sleep sec
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0) {
                        self?._forward_playlist(uri: url, from: Int(next.at))
                    }
                }
            }, onComplete: {
                log.info("done: forward_playlist")
            }
        )
    }

    func _pull_messages(uri: URL) {
        _retrieve(
            uri: uri,
            messageType: Dwango_Nicolive_Chat_Service_Edge_ChunkedMessage.self,
            onStream: {
                log.info($0)
            }, onComplete: {
                log.info("done: pull_messages")
            }
        )
    }

    func _retrieve<T: SwiftProtobuf.Message>(
        uri: URL,
        messageType: T.Type,
        onStream: @escaping (T) -> Void,
        onComplete: @escaping () -> Void
    ) {
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
                        onStream(parsed)
                    } catch {
                        log.error(error)
                        log.error(error.localizedDescription)
                    }
                }
            case .complete:
                // print(completion)
                // log.debug("done.")
                onComplete()
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
        return urlComponents.url!
    }
}
