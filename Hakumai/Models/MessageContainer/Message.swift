//
//  Message.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class Message {
    // workaround for non-supported class variable
    struct Static {
        static var messageNo: Int = 0
    }

    enum MessageType: Int {
        case system = 0
        case chat
    }

    // MARK: - Properties
    let messageNo: Int
    let messageType: MessageType
    let date: Date

    // property for system message
    let message: String?

    // property for chat message
    let chat: Chat?
    let firstChat: Bool?

    // MARK: - Object Lifecycle
    init(messageType: MessageType, message: String?, chat: Chat?, firstChat: Bool?) {
        self.messageType = messageType
        self.messageNo = Static.messageNo
        Static.messageNo += 1
        self.message = message
        self.chat = chat
        self.firstChat = firstChat
        self.date = Date()
    }

    convenience init(message: String) {
        self.init(messageType: .system, message: message, chat: nil, firstChat: nil)
    }

    convenience init(chat: Chat, firstChat: Bool = false) {
        self.init(messageType: .chat, message: nil, chat: chat, firstChat: firstChat)
    }

    // MARK: - Public Functions
    static func resetMessageNo() {
        Static.messageNo = 0
    }
}
