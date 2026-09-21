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
    func connect(viewUri: URL, beginTime: Date, diagnostics: ConnectionDiagnostics, resuming: Bool)
    func disconnect()
}

protocol NdgrClientDelegate: AnyObject {
    // Main connection sequence.
    func ndgrClientDidConnect(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics)
    func ndgrClientDidReceiveChat(_ ndgrClient: NdgrClientType, chat: Chat, diagnostics: ConnectionDiagnostics)
    func ndgrClientDidDisconnect(_ ndgrClient: NdgrClientType, diagnostics: ConnectionDiagnostics, reason: NdgrTermination)

    // History.
    func ndgrClientReceivingChatHistory(_ ndgrClient: NdgrClientType, requestCount: Int, totalChatCount: Int, diagnostics: ConnectionDiagnostics)
    func ndgrClientDidReceiveChatHistory(_ ndgrClient: NdgrClientType, chats: [Chat], diagnostics: ConnectionDiagnostics)
}

/// HTTP の読み取り完了だけでは放送終了と判定しない。
enum NdgrTermination {
    case programEnded
    case missingNext
    case failure(Error)
}

enum NdgrStreamError: Error {
    case programEnded
    case invalidSegmentURL
    case truncatedFrame
}
