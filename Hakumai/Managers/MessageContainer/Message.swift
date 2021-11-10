//
//  Message.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class Message {
    enum ContentType {
        case system(message: String)
        case chat(chat: Chat, first: Bool)
        case debug(message: String)
    }

    // MARK: - Properties
    let messageNo: Int
    let content: ContentType
    let date: Date

    // MARK: - Object Lifecycle
    init(messageNo: Int, content: ContentType) {
        self.messageNo = messageNo
        self.content = content
        self.date = Date()
    }

    convenience init(messageNo: Int, system: String) {
        self.init(
            messageNo: messageNo,
            content: .system(message: system)
        )
    }

    convenience init(messageNo: Int, chat: Chat, first: Bool = false) {
        self.init(
            messageNo: messageNo,
            content: .chat(chat: chat, first: first)
        )
    }

    convenience init(messageNo: Int, debug: String) {
        self.init(
            messageNo: messageNo,
            content: .debug(message: debug)
        )
    }
}
