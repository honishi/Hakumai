//
//  Message.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class Message {
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
    init(messageNo: Int, messageType: MessageType, message: String?, chat: Chat?, firstChat: Bool?) {
        self.messageNo = messageNo
        self.messageType = messageType
        self.message = message
        self.chat = chat
        self.firstChat = firstChat
        self.date = Date()
    }

    convenience init(messageNo: Int, message: String) {
        self.init(messageNo: messageNo, messageType: .system, message: message, chat: nil, firstChat: nil)
    }

    convenience init(messageNo: Int, chat: Chat, firstChat: Bool = false) {
        self.init(messageNo: messageNo, messageType: .chat, message: nil, chat: chat, firstChat: firstChat)
    }
}
