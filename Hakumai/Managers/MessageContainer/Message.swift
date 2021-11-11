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
        case system(message: String)
        case chat(chat: Chat, first: Bool)
        case debug(message: String)
    }

    // MARK: - Properties
    let messageNo: Int
    let content: ContentType
    let date: Date = Date()

    // MARK: - Object Lifecycle
    init(messageNo: Int, system: String) {
        self.messageNo = messageNo
        self.content = .system(message: system)
    }

    init(messageNo: Int, chat: Chat, first: Bool = false) {
        self.messageNo = messageNo
        self.content = .chat(chat: chat, first: first)
    }

    init(messageNo: Int, debug: String) {
        self.messageNo = messageNo
        self.content = .debug(message: debug)
    }
}
