//
//  NdgrClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2024/08/03.
//  Copyright © 2024 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class NdgrClient: NdgrClientType {
    // Public Properties
    weak var delegate: NdgrClientDelegate?
}

// MARK: - Public Functions
extension NdgrClient {
    func connect(viewUri: URL) {
        // TODO
        delegate?.ndgrClientDidConnect(self)
    }
}
