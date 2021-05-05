//
//  NicoUtilityModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/05.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - Live Page
struct EmbeddedDataProperties: Codable {
    struct Site: Codable {
        let relive: Relive
    }

    struct Relive: Codable {
        let webSocketUrl: String
    }

    let site: Site
}

// MARK: - WebSocket (Managing, Generic Model)
enum WebSocketDataType: String, Codable {
    case ping, room
}

struct WebSocketData: Codable {
    let type: WebSocketDataType
}

// MARK: - WebSocket (Managing, Specific Model)
struct WebSocketPingData: Codable {
    let type: WebSocketDataType
}

struct WebSocketRoomData: Codable {
    struct Data: Codable {
        let name: String
        let messageServer: MessageServer
        let threadId: String
        let yourPostKey: String
        let isFirst: Bool
        let waybackkey: String
    }

    struct MessageServer: Codable {
        let uri: String
        let type: String
    }

    let type: WebSocketDataType
    let data: Data
}

// MARK: - WebSocket (Message)
struct WebSocketChatData: Codable {
    struct WebSocketChat: Codable {
        let thread: String
        let no: Int
        let vpos: Int
        let date: Int
        let dateUsec: Int
        let mail: String
        let userId: String
        let premium: Int?
        let anonymity: Int
        let content: String
    }

    let chat: WebSocketChat
}
