//
//  NdgrClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2024/08/03.
//  Copyright © 2024 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

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
        session.request(
            viewUri,
            method: .get,
            parameters: ["at": Int(Date().timeIntervalSince1970)]
        )
        .validate()
        .responseData { [weak self] in
            guard let me = self else { return }
            switch $0.result {
            case .success(let data):
                log.debug(data)
                // TODO: message parse
            case .failure(let error):
                log.error("error in connecting to view: \(error)")
            }
            // TODO
            me.delegate?.ndgrClientDidConnect(me)
        }
    }
}
