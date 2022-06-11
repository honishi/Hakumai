//
//  KusaChecker.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/11.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kusaCheckInterval: TimeInterval = 2
private let kusaDetectRate = 0.2

final class KusaChecker {
    private weak var delegate: KusaCheckerDelegate?
    private var chats: [Chat] = []
    private var timer: Timer?

    // swiftlint:disable force_try
    private let kusaRegexp = try! NSRegularExpression(pattern: "^(w|W|ｗ|Ｗ){1,}$", options: [])
    private let aRegexp = try! NSRegularExpression(pattern: "^あ$", options: [])
    private let noRegexp = try! NSRegularExpression(pattern: "^ノ$", options: [])
    // swiftlint:enable force_try
}

extension KusaChecker: KusaCheckerType {
    func start(delegate: KusaCheckerDelegate) {
        self.delegate = delegate
        chats.removeAll()
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: kusaCheckInterval,
            target: self,
            selector: #selector(kusaCheckTimerFired),
            userInfo: nil,
            repeats: true)
        delegate.kusaChecker(self, hasDebugMessage: "KusaChecker started.")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        delegate?.kusaChecker(self, hasDebugMessage: "KusaChecker stopped.")
    }

    func add(chat: Chat) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        chats.append(chat)
    }
}

private extension KusaChecker {
    @objc
    func kusaCheckTimerFired() {
        refreshChats()
        let rate = calcurateKusaRate()
        delegate?.kusaChecker(self, hasDebugMessage: "Kusa rate: \(Int(rate * 100))")
        if rate > kusaDetectRate {
            delegate?.kusaCheckerDidDetectKusa(self)
        }
        debugLog(rate: rate)
    }

    func refreshChats() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        // Refresh chats array as follows:
        // * Discards old chats.
        // * Filter by unique user id.
        // * Pick some latest chats only.
        chats = chats
            .filter { -10 < $0.date.timeIntervalSinceNow }
            .reduce([]) { $0.map({ $0.userId }).contains($1.userId) ? $0 : $0 + [$1] }
            .suffix(20)
    }

    func calcurateKusaRate() -> Double {
        if chats.isEmpty || chats.count < 3 {
            return 0
        }
        let kusaChats = chats.filter { isKusaComment($0.comment) }
        return Double(kusaChats.count) / Double(chats.count)
    }

    func isKusaComment(_ comment: String) -> Bool {
        // Is matched in these?: "ｗ", "ｗｗ", ..., "あ", "ノ"
        return (
            comment.isMatched(regexp: kusaRegexp) ||
                comment.isMatched(regexp: aRegexp) ||
                comment.isMatched(regexp: noRegexp)
        )
    }

    func debugLog(rate: Double) {
        log.debug("========= ========= ========= ========= ========= =========")
        log.debug("rate:\(Int(rate * 100)), count:\(chats.count), last:\(chats.last?.comment ?? "")")
        chats.forEach {
            log.debug("\(isKusaComment($0.comment)), \($0.comment)")
        }
    }
}

extension String {
    func isMatched(regexp: NSRegularExpression) -> Bool {
        regexp.firstMatch(
            in: self,
            options: [],
            range: NSRange(location: 0, length: count)
        ) != nil
    }
}
