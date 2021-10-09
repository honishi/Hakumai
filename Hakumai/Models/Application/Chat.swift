//
//  Chat.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class Chat: CustomStringConvertible {
    let roomPosition: RoomPosition = .arena
    let no: Int
    let date: Date
    let dateUsec: Int
    let mail: [String]?
    let userId: String
    let comment: String
    let premium: Premium

    var isRawUserId: Bool { Chat.isRawUserId(userId) }
    var isUserComment: Bool { Chat.isUserComment(premium) }
    var isSystemComment: Bool { Chat.isSystemComment(premium) }
    var hasUserIcon: Bool { isUserComment && isRawUserId }

    var description: String {
        return (
            "Chat: roomPosition[\(roomPosition.description)] no[\(no)] " +
                "date[\(date.description)] dateUsec[\(dateUsec)] mail[\(mail ?? [])] userId[\(userId)] " +
                "premium[\(premium.description)] comment[\(comment)]"
        )
    }

    // MARK: - Object Lifecycle
    init(no: Int, date: Date, dateUsec: Int, mail: [String]?, userId: String, comment: String, premium: Premium) {
        self.no = no
        self.date = date
        self.dateUsec = dateUsec
        self.mail = mail
        self.userId = userId
        // self.comment = comment
        self.comment = Chat.replaceSlashCommand(comment: comment, premium: premium)
        self.premium = premium
    }
}

// MARK: - Public Functions
extension Chat {
    static func isRawUserId(_ userId: String?) -> Bool {
        guard let regexp = try? NSRegularExpression(pattern: "^\\d+$", options: []),
              let userId = userId else { return false }
        let matched = regexp.firstMatch(
            in: userId,
            options: [],
            range: NSRange(location: 0, length: userId.utf16.count))
        return matched != nil
    }

    static func isUserComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else { return false }
        return premium == .ippan || premium == .premium || premium == .ippanTransparent
    }

    static func isSystemComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else { return false }
        return premium == .system || premium == .caster || premium == .operator
    }
}

private let commentPreReplacePatterns = [
    // "/gift champagne_2 14560037 \"空気\" 900 \"\" \"シャンパーン\" 1"
    // "/gift 空気さんがギフト「シャンパーン(900pt)」を贈りました"
    ("^(/gift ).+ .+ \"(.+?)\" (\\d+?) \".*?\" \"(.+?)\".*$", "$1$2さんがギフト「$4($3pt)」を贈りました"),
    // "/info 10 「横山緑」が好きな1人が来場しました"
    // "/info 「横山緑」が好きな1人が来場しました"
    ("^(/info )\\d+? (.+)$", "$1$2"),
    // "/nicoad {\"totalAdPoint\":15800,\"message\":\"【広告貢献1位】makimakiさんが2100ptニコニ広告しました\",\"version\":\"1\"}"
    // "/nicoad 【広告貢献1位】makimakiさんが2100ptニコニ広告しました"
    ("^(/nicoad ).+\"message\":\"(.+?)\".+$", "$1$2"),
    // "/vote start お墓 継ぐ 継がない 自分の代で終わらせる"
    // "/vote アンケ start お墓 継ぐ 継がない 自分の代で終わらせる"
    ("^(/vote )(.+)$", "$1アンケ $2"),
    ("^(/\\w+ )\"(.+)\"$", "$1$2")
]

private let commentEmojiReplacePatterns = [
    ("^/cruise ", "⚓️ "),
    ("^/emotion ", "💬 "),
    ("^/gift ", "🎁 "),
    ("^/info ", "ℹ️ "),
    ("^/nicoad ", "📣 "),
    ("^/quote ", "⛴ "),
    ("^/spi ", "🎮 "),
    ("^/vote ", "🙋‍♂️ ")
]

extension Chat {
    static func replaceSlashCommand(comment: String, premium: Premium) -> String {
        guard premium == .caster, comment.starts(with: "/") else { return comment }
        var replaced = comment
        commentPreReplacePatterns.forEach {
            replaced = replaced.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        commentEmojiReplacePatterns.forEach {
            replaced = replaced.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        return replaced
    }
}
