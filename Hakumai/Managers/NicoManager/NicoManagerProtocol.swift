//
//  NicoManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/16.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - Protocol
protocol NicoManagerType: AnyObject {
    // Properties
    var delegate: NicoManagerDelegate? { get set }
    var live: Live? { get }

    // Main Methods
    func connect(liveProgramId: String)
    func disconnect()
    func reconnect(reason: NicoReconnectReason)
    func comment(_ comment: String, anonymously: Bool, completion: @escaping (_ comment: String?) -> Void)
    func logout()

    // Methods for User Accounts
    func cachedUserName(for userId: String) -> String?
    func resolveUsername(for userId: String, completion: @escaping (String?) -> Void)
    func userPageUrl(for userId: String) -> URL?
    func userIconUrl(for userId: String) -> URL?

    // Misc Methods
    func livePageUrl(for liveProgramId: String) -> URL?
    func communityPageUrl(for communityId: String) -> URL?
    func adPageUrl(for liveProgramId: String) -> URL?
    func giftPageUrl(for communityId: String) -> URL?

    // Debug Methods
    func injectExpiredAccessToken()
}

// Note these functions are called in background thread, not main thread.
// So use explicit main thread for updating UI components from these callbacks.
protocol NicoManagerDelegate: AnyObject {
    // Token check results before proceeding to main connection sequence.
    func nicoManagerNeedsToken(_ nicoManager: NicoManagerType)
    func nicoManagerDidConfirmTokenExistence(_ nicoManager: NicoManagerType)

    // Main connection sequence.
    func nicoManagerWillPrepareLive(_ nicoManager: NicoManagerType)
    func nicoManagerDidPrepareLive(_ nicoManager: NicoManagerType, user: User, live: Live, connectContext: NicoConnectContext)
    func nicoManagerDidFailToPrepareLive(_ nicoManager: NicoManagerType, error: NicoError)
    func nicoManagerDidConnectToLive(_ nicoManager: NicoManagerType, roomPosition: RoomPosition, connectContext: NicoConnectContext)

    // Events after connection establishment.
    func nicoManagerDidReceiveChat(_ nicoManager: NicoManagerType, chat: Chat)
    func nicoManagerWillReconnectToLive(_ nicoManager: NicoManagerType, reason: NicoReconnectReason)
    func nicoManagerDidReceiveStatistics(_ nicoManager: NicoManagerType, stat: LiveStatistics)

    // History.
    func nicoManagerReceivingChatHistory(_ nicoManager: NicoManagerType, requestCount: Int, totalChatCount: Int)
    func nicoManagerDidReceiveChatHistory(_ nicoManager: NicoManagerType, chats: [Chat])

    // Disconnect.
    func nicoManagerDidDisconnect(_ nicoManager: NicoManagerType, disconnectContext: NicoDisconnectContext)

    // Debug.
    func nicoManager(_ nicoManager: NicoManagerType, hasDebugMessgae message: String)
}

enum NicoError: Error {
    case `internal`
    case noLiveInfo
    case noMessageServerInfo
    case openMessageServerFailed
    case notStarted
}

enum NicoConnectContext {
    case normal
    case reconnect(NicoReconnectReason)

    var isReconnect: Bool {
        switch self {
        case .normal:
            return false
        case .reconnect:
            return true
        }
    }
}

enum NicoDisconnectContext {
    case normal
    case reconnect(NicoReconnectReason)
}

enum NicoReconnectReason { case normal, noPong, noTexts }
