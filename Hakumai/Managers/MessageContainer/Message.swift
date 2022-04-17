//
//  Message.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct Message {
    // MARK: - Types
    enum ContentType {
        case system(SystemMessage)
        case chat(ChatMessage)
        case debug(DebugMessage)
    }

    // MARK: - Properties
    let messageNo: Int
    let content: ContentType
    let date: Date = Date()

    // MARK: - Object Lifecycle
    init(messageNo: Int, system: String) {
        self.messageNo = messageNo
        self.content = .system(SystemMessage(message: system))
    }

    init(messageNo: Int, chat: Chat, isFirst: Bool = false) {
        self.messageNo = messageNo
        self.content = .chat(chat.toChatMessage(isFirst: isFirst))
    }

    init(messageNo: Int, debug: String) {
        self.messageNo = messageNo
        self.content = .debug(DebugMessage(message: debug))
    }
}

extension Message {
    var isGift: Bool { giftImageUrl != nil }

    var giftImageUrl: URL? {
        switch content {
        case .chat(let chat):
            guard let slashCommand = chat.slashCommand else { return nil }
            switch slashCommand {
            case .gift(let url):
                return url
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - Individual Message
struct SystemMessage {
    let message: String
}

struct ChatMessage {
    let no: Int
    let date: Date
    let userId: String
    let comment: String
    let premium: Premium
    let isFirst: Bool
    let slashCommand: SlashCommand?
}

struct DebugMessage {
    let message: String
}

// MARK: - ChatMessage Extension
extension ChatMessage {
    var isRawUserId: Bool { userId.isRawUserId }
    var isUser: Bool { premium.isUser }
    var isSystem: Bool { premium.isSystem }
    var hasUserIcon: Bool { isUser && isRawUserId }
    var isCasterComment: Bool { premium == .caster && slashCommand == nil }
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

private let giftIdExtractPattern = ("^/gift (.+?) .*$", "$1")
private let giftImageUrl = "https://secure-dcdn.cdn.nimg.jp/nicoad/res/nage/thumbnail/%@.png"

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

extension String {
    func htmlTagRemoved(premium: Premium) -> String {
        guard premium == .caster, hasRegexp(pattern: "https?://") else { return self }
        return stringByRemovingRegexp(pattern: "<[^>]*>")
    }

    func slashCommandReplaced(premium: Premium) -> String {
        guard premium == .caster, starts(with: "/") else { return self }
        var replaced = self
        commentPreReplacePatterns.forEach {
            replaced = replaced.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        commentEmojiReplacePatterns.forEach {
            replaced = replaced.stringByReplacingRegexp(pattern: $0.0, with: $0.1)
        }
        return replaced
    }
}

enum SlashCommand: Equatable {
    case cruise, emotion, info, nicoad, quote, spi, vote
    case gift(URL)
    case unknown
}

// MARK: - Model Mapper
extension Chat {
    func toChatMessage(isFirst: Bool) -> ChatMessage {
        return ChatMessage(
            no: no,
            date: date,
            userId: userId,
            comment: comment
                .htmlTagRemoved(premium: premium)
                .slashCommandReplaced(premium: premium),
            premium: premium,
            isFirst: isFirst,
            slashCommand: toSlashCommand()
        )
    }

    func toSlashCommand() -> SlashCommand? {
        guard premium == .caster else { return nil }
        return Chat.toSlashCommand(from: comment)
    }

    static func toSlashCommand(from comment: String) -> SlashCommand? {
        guard comment.hasRegexp(pattern: "^/\\w+ .+$") else {
            return nil
        }
        if comment.hasPrefix("/cruise ") {
            return .cruise
        } else if comment.hasPrefix("/emotion ") {
            return .emotion
        } else if let gift = comment.toGift() {
            return gift
        } else if comment.hasPrefix("/info ") {
            return .info
        } else if comment.hasPrefix("/nicoad ") {
            return .nicoad
        } else if comment.hasPrefix("/quote ") {
            return .quote
        } else if comment.hasPrefix("/spi ") {
            return .spi
        } else if comment.hasPrefix("/vote ") {
            return .vote
        }
        return .unknown
    }
}

private extension String {
    func toGift() -> SlashCommand? {
        guard hasRegexp(pattern: giftIdExtractPattern.0) else { return nil }
        let giftId = stringByReplacingRegexp(
            pattern: giftIdExtractPattern.0,
            with: giftIdExtractPattern.1
        )
        let urlString = String(format: giftImageUrl, giftId)
        guard let url = URL(string: urlString) else { return nil }
        return .gift(url)
    }
}
