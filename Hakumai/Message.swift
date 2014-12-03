//
//  Message.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/3/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class Message {
    enum MessageType: Int {
        case System = 0
        case Chat
    }

    // MARK: - Properties
    let messageType: MessageType
    let date: NSDate

    // property for system message
    let message: String?
    
    // property for chat message
    let chat: Chat?
    let firstChat: Bool?

    // MARK: - Object Lifecycle
    init(messageType: MessageType, message: String?, chat: Chat?, firstChat: Bool?) {
        self.messageType = messageType
        self.message = message
        self.chat = chat
        self.firstChat = firstChat
        self.date = NSDate()
    }
    
    convenience init(message: String) {
        self.init(messageType: .System, message: message, chat: nil, firstChat: nil)
    }
    
    convenience init(chat: Chat, firstChat: Bool = false) {
        self.init(messageType: .Chat, message: nil, chat: chat, firstChat: firstChat)
    }
}