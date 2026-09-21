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
    func connect(viewUri: URL, beginTime: Date, diagnostics: ConnectionDiagnostics)
    func disconnect()
}

protocol NdgrClientDelegate: AnyObject {
    // Main connection sequence.
    func ndgrClientDidConnect(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics)
    func ndgrClientDidReceiveChat(_ ndgrClient: NdgrClientType, chat: Chat)
    func ndgrClientDidDisconnect(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics?)

    // History.
    func ndgrClientReceivingChatHistory(_ ndgrClient: NdgrClientType, requestCount: Int, totalChatCount: Int)
    func ndgrClientDidReceiveChatHistory(_ ndgrClient: NdgrClientType, chats: [Chat])
}
