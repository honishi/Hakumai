//
//  NdgrClientProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2024/08/03.
//  Copyright © 2024 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol NdgrClientType: AnyObject {
    // Properties
    var delegate: NdgrClientDelegate? { get set }

    // Main Methods
    func connect(viewUri: URL)
}

protocol NdgrClientDelegate: AnyObject {
    // Main connection sequence.
    func ndgrClientDidConnect(_ ndgrClient: NdgrClientType)
}
