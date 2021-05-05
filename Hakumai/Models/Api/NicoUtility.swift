//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import XCGLogger

// MARK: - Protocol
// note these functions are called in background thread, not main thread.
// so use explicit main thread for updating ui in these callbacks.
protocol NicoUtilityDelegate: AnyObject {
    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtilityType, user: User, live: Live)
    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtilityType, reason: String)
    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtilityType, roomPosition: RoomPosition)
    func nicoUtilityDidReceiveFirstChat(_ nicoUtility: NicoUtilityType, chat: Chat)
    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtilityType, chat: Chat)
    func nicoUtilityDidGetKickedOut(_ nicoUtility: NicoUtilityType)
    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtilityType)
    func nicoUtilityDidReceiveHeartbeat(_ nicoUtility: NicoUtilityType, heartbeat: Heartbeat)
}

protocol NicoUtilityType {
    // Properties
    static var shared: Self { get }
    var delegate: NicoUtilityDelegate? { get }
    var live: Live? { get }

    // Main Methods
    func connect(liveNumber: Int, connectType: NicoConnectType)
    func disconnect(reserveToReconnect: Bool)
    func comment(_ comment: String, anonymously: Bool, completion: @escaping (_ comment: String?) -> Void)
    func checkHeartbeat(_ timer: Timer)

    // Methods for Community and Usernames
    func loadThumbnail(completion: @escaping (Data?) -> Void)
    func cachedUserName(forChat chat: Chat) -> String?
    func cachedUserName(forUserId userId: String) -> String?
    func resolveUsername(forUserId userId: String, completion: @escaping (String?) -> Void)
    func extractUsername(fromHtmlData htmlData: Data) -> String?

    // Utility Methods
    func urlString(forUserId userId: String) -> String
    func reserveToClearUserSessionCookie()

    // Miscellaneous Methods
    func reportAsNgUser(chat: Chat, completion: @escaping (_ userId: String?) -> Void)
}

// MARK: - Types
enum NicoConnectType {
    case chrome
    case safari
    case login(mail: String, password: String)
}

enum NicoUtilityError: Error {
    case network
    case `internal`
    case unknown
}

// MARK: - Constants
private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36"
private let livePageUrl = "https://live.nicovideo.jp/watch/lv"

// MARK: - Class
final class NicoUtility: NicoUtilityType {
    // Public Properties
    static var shared: NicoUtility = NicoUtility()
    weak var delegate: NicoUtilityDelegate?
    private(set) var live: Live?

    // Private Properties
    private var lastLiveNumber: Int?
    private var userSessionCookie: String?
    private let session: Session

    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.headers.add(.userAgent(userAgent))
        self.session = Session(configuration: configuration)
    }
}

// MARK: - Public Methods
extension NicoUtility {
    func connect(liveNumber: Int, connectType: NicoConnectType) {
        let completion = { (userSessionCookie: String?) -> Void in
            self.connect(liveNumber: liveNumber, userSessionCookie: userSessionCookie)
        }
        switch connectType {
        case .chrome:
            CookieUtility.requestBrowserCookie(browserType: .chrome, completion: completion)
        case .safari:
            CookieUtility.requestBrowserCookie(browserType: .safari, completion: completion)
        case .login(let mail, let password):
            CookieUtility.requestLoginCookie(mailAddress: mail, password: password, completion: completion)
        }
    }

    func disconnect(reserveToReconnect: Bool = false) {
        //
    }

    func comment(_ comment: String, anonymously: Bool, completion: @escaping (String?) -> Void) {
        //
    }

    @objc func checkHeartbeat(_ timer: Timer) {
        //
    }

    func urlString(forUserId userId: String) -> String {
        return ""
    }

    func reserveToClearUserSessionCookie() {
        //
    }

    func loadThumbnail(completion: @escaping (Data?) -> Void) {
        //
    }

    func cachedUserName(forChat chat: Chat) -> String? {
        return nil
    }

    func cachedUserName(forUserId userId: String) -> String? {
        return nil
    }

    func resolveUsername(forUserId userId: String, completion: @escaping (String?) -> Void) {
        //
    }

    func extractUsername(fromHtmlData htmlData: Data) -> String? {
        return nil
    }

    func reportAsNgUser(chat: Chat, completion: @escaping (String?) -> Void) {
        //
    }
}

// MARK: - Private Methods
private extension NicoUtility {
    func connect(liveNumber: Int, userSessionCookie: String?) {
        guard let userSessionCookie = userSessionCookie else {
            let reason = "No available cookie."
            log.error(reason)
            delegate?.nicoUtilityDidFailToPrepareLive(self, reason: reason)
            return
        }

        self.userSessionCookie = userSessionCookie
        self.lastLiveNumber = liveNumber

        // TODO: use cookie

        delegate?.nicoUtilityWillPrepareLive(self)
        _requestLiveInfo(lv: liveNumber)
    }

    func _requestLiveInfo(lv: Int) {
        reqeustLiveInfo(lv: lv) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let webSocketUrl):
                me._reqeustMessageServerInfo(webSocketUrl: webSocketUrl)
            case .failure(_):
                let reason = "Failed to load live info."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason)
            }
        }
    }

    func _reqeustMessageServerInfo(webSocketUrl: String) {
        requestMessageServerInfo(webSocketUrl: webSocketUrl) { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success():
                // TODO: Start to connect to message server..
                me.delegate?.nicoUtilityDidConnectToLive(me, roomPosition: RoomPosition.arena)
            case .failure(_):
                let reason = "Failed to load message server info."
                me.delegate?.nicoUtilityDidFailToPrepareLive(me, reason: reason)
            }
        }
    }

    func reqeustLiveInfo(lv: Int, completion: @escaping (Result<String, NicoUtilityError>) -> Void) {
        let url = livePageUrl + "\(lv)"
        session.request(url).responseData { [weak self] in
            self?._logAfResponse($0)
            switch $0.result {
            case .success(let data):
                guard let webSocketUrl = NicoUtility.extractWebSocketUrlFromLivePage(html: data) else {
                    completion(Result.failure(NicoUtilityError.internal))
                    return
                }
                completion(Result.success(webSocketUrl))
            case .failure(_):
                completion(Result.failure(NicoUtilityError.internal))
            }
        }
    }

    func requestMessageServerInfo(webSocketUrl: String, completion: (Result<Void, NicoUtilityError>) -> Void) {
        // TODO: websockets
    }
}

// MARK: - Private Utility Methods
private extension NicoUtility {
    func customHeaders() -> [String: String] {
        return [:]
    }
}

private extension NicoUtility {
    func _logAfResponse(_ response: AFDataResponse<Data>) {
        log.debug(response.debugDescription)
        log.debug(response.request?.debugDescription)
        log.debug(response.request?.headers)
        log.debug(response)
    }
}
