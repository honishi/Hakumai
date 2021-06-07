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
    static var shared: Self { get }
    var delegate: NicoUtilityDelegate? { get }
    var live: Live? { get }

    // Main Methods
    func connect(liveNumber: Int, sessionType: NicoUtility.SessionType, connectContext: NicoUtility.ConnectContext)
    func disconnect(disconnectContext: NicoUtility.DisconnectContext)
    func reconnect(reason: NicoUtility.ReconnectReason)
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
}

// note these functions are called in background thread, not main thread.
// so use explicit main thread for updating ui in these callbacks.
protocol NicoUtilityDelegate: AnyObject {
    func nicoUtilityNeedsLogin(_ nicoUtility: NicoUtilityType)
    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtilityType, user: User, live: Live, connectContext: NicoUtility.ConnectContext)
    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtilityType, error: NicoUtility.NicoError)
    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtilityType, roomPosition: RoomPosition, connectContext: NicoUtility.ConnectContext)
    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtilityType, chat: Chat)
    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtilityType, reason: NicoUtility.ReconnectReason)
    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtilityType, disconnectContext: NicoUtility.DisconnectContext)
    func nicoUtilityDidReceiveStatistics(_ nicoUtility: NicoUtilityType, stat: LiveStatistics)
}
