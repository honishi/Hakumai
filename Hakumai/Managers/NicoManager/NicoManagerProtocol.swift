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
    func cachedUserName(forChat chat: Chat) -> String?
    func cachedUserName(forUserId userId: String) -> String?
    func resolveUsername(forUserId userId: String, completion: @escaping (String?) -> Void)
    func userPageUrl(for userId: String) -> URL?
    func userIconUrl(for userId: String) -> URL?

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

    // Disconnect.
    func nicoManagerDidDisconnect(_ nicoManager: NicoManagerType, disconnectContext: NicoDisconnectContext)
}

enum NicoError: Error {
    case `internal`
    case noLiveInfo
    case noMessageServerInfo
    case openMessageServerFailed
}

enum NicoConnectContext {
    case normal
    case reconnect(NicoReconnectReason)
}

enum NicoDisconnectContext {
    case normal
    case reconnect(NicoReconnectReason)
}

enum NicoReconnectReason { case normal, noPong, noTexts }
