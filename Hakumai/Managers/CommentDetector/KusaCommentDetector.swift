//
//  KusaCommentDetector.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/11.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kusaCheckInterval: TimeInterval = 2
private let kusaDetectRate = 0.3

final class KusaCommentDetector {
    private weak var delegate: KusaCommentDetectorDelegate?
    private var chats: [Chat] = []
    private var timer: Timer?

    // swiftlint:disable force_try
    private let kusaRegexp = try! NSRegularExpression(pattern: "^(w|W|ｗ|Ｗ){1,}$", options: [])
    private let waraRegexp = try! NSRegularExpression(pattern: "^.+(w|W|ｗ|Ｗ){1,}$", options: [])
    private let aRegexp = try! NSRegularExpression(pattern: "^あ$", options: [])
    private let eRegexp = try! NSRegularExpression(pattern: "^え$", options: [])
    private let noRegexp = try! NSRegularExpression(pattern: "^ノ$", options: [])
    // swiftlint:enable force_try
}

extension KusaCommentDetector: KusaCommentDetectorType {
    func start(delegate: KusaCommentDetectorDelegate) {
        self.delegate = delegate
        chats.removeAll()
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: kusaCheckInterval,
            target: self,
            selector: #selector(kusaCheckTimerFired),
            userInfo: nil,
            repeats: true)
        delegate.kusaCommentDetector(self, hasDebugMessage: "KusaChecker started.")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        delegate?.kusaCommentDetector(self, hasDebugMessage: "KusaChecker stopped.")
    }

    func add(chat: Chat) {
        guard chat.isComment else { return }
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        chats.append(chat)
    }
}

private extension KusaCommentDetector {
    @objc
    func kusaCheckTimerFired() {
        refreshChats()
        let rate = calcurateKusaRate()
        delegate?.kusaCommentDetector(self, hasDebugMessage: "Kusa rate: \(Int(rate * 100)) %")
        if rate > kusaDetectRate {
            delegate?.kusaCommentDetectorDidDetectKusa(self)
        }
        // debugLog(rate: rate)
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
        objc_sync_enter(self)
        let snapshot = chats
        objc_sync_exit(self)
        if snapshot.count < 5 {
            return 0
        }
        let kusaChats = snapshot.filter { isKusaComment($0.comment) }
        return Double(kusaChats.count) / Double(snapshot.count)
    }

    func isKusaComment(_ comment: String) -> Bool {
        // Is matched in these?: "ｗ", "ｗｗ", ..., "あ", "ノ"
        return (
            comment.isMatched(regexp: kusaRegexp) ||
                comment.isMatched(regexp: waraRegexp) ||
                comment.isMatched(regexp: aRegexp) ||
                comment.isMatched(regexp: eRegexp) ||
                comment.isMatched(regexp: noRegexp)
        )
    }

    func debugLog(rate: Double) {
        log.debug("========= ========= ========= ========= ========= =========")
        log.debug("rate: \(Int(rate * 100)) %, count: \(chats.count)")
        chats.forEach {
            log.debug("\(isKusaComment($0.comment) ? "🔵 true" : "⚪️ false"), \($0.comment)")
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
