//
//  NicoUtilityProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/16.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - Protocol
protocol NicoUtilityType {
    // Properties
    static var shared: NicoUtilityType { get }
    var delegate: NicoUtilityDelegate? { get set }
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

    // Miscellaneous Methods
    func reportAsNgUser(chat: Chat, completion: @escaping (_ userId: String?) -> Void)

    // Debug Methods
    func injectExpiredAccessToken()
}

// Note these functions are called in background thread, not main thread.
// So use explicit main thread for updating UI components from these callbacks.
protocol NicoUtilityDelegate: AnyObject {
    // Token check results before proceeding to main connection sequence.
    func nicoUtilityNeedsToken(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidConfirmTokenExistence(_ nicoUtility: NicoUtilityType)

    // Main connection sequence.
    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtilityType, user: User, live: Live, connectContext: NicoConnectContext)
    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtilityType, error: NicoError)
    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtilityType, roomPosition: RoomPosition, connectContext: NicoConnectContext)

    // Events after connection establishment.
    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtilityType, chat: Chat)
    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtilityType, reason: NicoReconnectReason)
    func nicoUtilityDidReceiveStatistics(_ nicoUtility: NicoUtilityType, stat: LiveStatistics)

    // Disconnect.
    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtilityType, disconnectContext: NicoDisconnectContext)
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
enum NicoReconnectReason { case normal, noPong, noTexts }
enum NicoDisconnectContext { case normal, reconnect }
