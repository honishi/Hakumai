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
            switch chat.chatType {
            case .gift(imageUrl: let imageUrl):
                return imageUrl
            case .comment, .nicoad, .other:
                return nil
            }
        default:
            return nil
        }
    }

    var isAd: Bool {
        switch content {
        case .chat(let chat):
            switch chat.chatType {
            case .nicoad:
                return true
            case .comment, .gift, .other:
                return false
            }
        default:
            return false
        }
    }
}

// MARK: - Individual Message
struct SystemMessage {
    let message: String
}

struct ChatMessage {
    let roomPosition: RoomPosition
    let no: Int
    let date: Date
    let userId: String
    let comment: String
    let premium: Premium
    let isFirst: Bool
    let chatType: ChatType
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
    var isCasterComment: Bool { premium == .caster }
}

// TODO: ndgr client に移行する。
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
}

// MARK: - Model Mapper
extension Chat {
    func toChatMessage(isFirst: Bool) -> ChatMessage {
        return ChatMessage(
            roomPosition: roomPosition,
            no: no,
            date: date,
            userId: userId,
            comment: comment
                .htmlTagRemoved(premium: premium),
            premium: premium,
            isFirst: isFirst,
            chatType: chatType
        )
    }
}
