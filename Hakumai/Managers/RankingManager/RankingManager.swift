//
//  RankingManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/30.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire
import Kanna

private let queryInterval: TimeInterval = 60
private let chikuranUrl = "https://www.chikuwachan.com/live/ajax.cgi?column=1&sites=NCU"
private let maxPage = 5

final class RankingManager {
    static let shared = RankingManager()

    var isRunning: Bool { queryTimer != nil && queryTimer?.isValid == true }

    // [(liveId, weak reference to delegate object)]
    private var delegates: [(String, WeakDelegateReference)] = []
    // Key: [liveId] -> Value: [ranking value]
    private var rankMap: [String: Int] = [:]
    private var rankUpdatedDate: Date?
    private var queryTimer: Timer?
    private var isQuerying = false
}

extension RankingManager: RankingManagerType {
    func addDelegate(_ delegate: RankingManagerDelegate, for liveId: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        // De-register the delegate before registering, just in case.
        delegates = delegates.filter { $0.1.delegate !== delegate }
        delegates.append((liveId, WeakDelegateReference(delegate: delegate)))
        logDelegates()
        scheduleQueryTimerIfNeeded()
        // Just in case, notify rank immediately with latest rank map.
        notifyUpdatedRankToDelegates()
    }

    func removeDelegate(_ delegate: RankingManagerDelegate) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        delegates = delegates.filter { $0.1.delegate !== delegate }
        logDelegates()
        invalidateQueryTimerIfNeeded()
    }
}

private extension RankingManager {
    func scheduleQueryTimerIfNeeded() {
        guard queryTimer == nil else {
            logDebugMessage("Query already scheduled, skip query timer scheduling.")
            return
        }
        queryTimer = Timer.scheduledTimer(
            timeInterval: queryInterval,
            target: self,
            selector: #selector(RankingManager.queryRank),
            userInfo: nil,
            repeats: true)
        logDebugMessage("Query timer scheduled.")
        queryTimer?.fire()
    }

    func invalidateQueryTimerIfNeeded() {
        guard queryTimer != nil else {
            logDebugMessage("Query already not invalidated, skip query timer invalidating.")
            return
        }
        guard delegates.isEmpty else {
            logDebugMessage("There're \(delegates.count) delegate(s) registered, skip query timer invalidating.")
            return
        }
        queryTimer?.invalidate()
        queryTimer = nil
        logDebugMessage("Query timer invalidated.")
    }

    @objc func queryRank() {
        guard !isQuerying else {
            logDebugMessage("Seems the rank querying is in progress, skip to proceed.")
            return
        }
        rankMap.removeAll()
        rankUpdatedDate = nil
        isQuerying = true
        notifyDebugMessageToDelegates("Started query...")
        _queryRank(page: 1)
    }

    func _queryRank(page: Int) {
        // logDebugMessage("Processing page \(page).")
        var request = URLRequest(url: rankingUrl(for: page))
        request.headers = [commonUserAgentKey: commonUserAgentValue]
        AF.request(request)
            // .cURLDescription { log.debug($0) }
            .validate()
            .responseString { [weak self] in
                guard let me = self else { return }
                switch $0.result {
                case .success(let html):
                    let map = me.extractRankMap(from: html)
                    me.rankMap.merge(map) { (_, map) in map }
                    if page < maxPage {
                        // Continue to request further page recursively.
                        let nextPage = page + 1
                        // me.logDebugMessage("Continue further query, page -> \(nextPage)")
                        me._queryRank(page: nextPage)
                        return
                    }
                    me.rankUpdatedDate = Date()
                    me.notifyUpdatedRankToDelegates()
                case .failure(let error):
                    // No-op.
                    me.logDebugMessage("Failed at page \(page), \(error.localizedDescription)")
                }
                me.isQuerying = false
                me.notifyDebugMessageToDelegates("Finished query.")
            }
    }

    func rankingUrl(for page: Int) -> URL {
        let urlString = chikuranUrl
            + (page == 1 ? "" : "&page=\(page)")
            + "&_=\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let url = URL(string: urlString) else {
            fatalError("This case is not going to be happened.")
        }
        return url
    }

    func extractRankMap(from html: String) -> [String: Int] {
        var map: [String: Int] = [:]
        guard let doc = try? HTML(html: html, encoding: .utf8) else { return map }
        for live in doc.xpath("//li[contains(@class, \"live\")]") {
            guard let rankText = live.xpath("//div[@class=\"rank\"]").first?.text,
                  let rank = Int(rankText),
                  let linkText = live.xpath("//a[@class=\"liveurl\"]").first?["href"],
                  let liveId = linkText.extractLiveProgramId() else { continue }
            map[liveId] = rank
        }
        return map
    }

    func notifyUpdatedRankToDelegates() {
        // log.debug(rankMap)
        delegates.forEach { liveId, reference in
            let rank = self.rankMap[liveId]
            logDebug(rank: rank, liveId: liveId, delegate: reference.delegate)
            reference.delegate?.rankingManager(self, didUpdateRank: rank, for: liveId, at: rankUpdatedDate)
        }
    }
}

// MARK: Debug Methods
private extension RankingManager {
    func logDelegates() {
        log.debug(delegates)
    }

    func logDebugMessage(_ message: String) {
        log.debug(message)
        notifyDebugMessageToDelegates(message)
    }

    func notifyDebugMessageToDelegates(_ message: String) {
        let _message = "Rank: " + message
        delegates.forEach { $0.1.delegate?.rankingManager(self, hasDebugMessage: _message) }
    }

    func logDebug(rank: Int?, liveId: String, delegate: RankingManagerDelegate?) {
        let _rank = { () -> String in
            guard let rank = rank else { return "-" }
            return String(rank)
        }()
        let _delegate = "\(String(describing: delegate))".extractRegexp(pattern: ".+(0x.+)>") ?? "-"
        self.notifyDebugMessageToDelegates("Notifying rank #\(_rank) for \(liveId) → \(_delegate)")
    }
}

// https://stackoverflow.com/a/51487124/13220031
private final class WeakDelegateReference {
    private(set) weak var delegate: RankingManagerDelegate?

    init(delegate: RankingManagerDelegate?) {
        self.delegate = delegate
    }
}

// Extension for unit testing.
// https://stackoverflow.com/a/50136916/13220031
#if DEBUG
extension RankingManager {
    func exposedExtractRankMap(from html: String) -> [String: Int] {
        return extractRankMap(from: html)
    }
}
#endif
