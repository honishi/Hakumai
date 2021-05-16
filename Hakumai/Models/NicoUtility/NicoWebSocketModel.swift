//
//  NicoWebSocketModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/16.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - WebSocket (Managing, Generic Model)
enum WebSocketDataType: String, Codable {
    case ping, seat, room, statistics, disconnect
}

struct WebSocketData: Codable {
    let type: WebSocketDataType
}

// MARK: - WebSocket (Managing, Specific Model)
struct WebSocketPingData: Codable {
    let type: WebSocketDataType
}

struct WebSocketSeatData: Codable {
    struct Data: Codable {
        let keepIntervalSec: Int
    }

    let type: WebSocketDataType
    let data: Data
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

struct WebSocketStatisticsData: Codable {
    struct Data: Codable {
        let viewers: Int
        let comments: Int
        let adPoints: Int?
        let giftPoints: Int?
    }

    let type: WebSocketDataType
    let data: Data
}

struct WebSocketDisconnectData: Codable {
    let type: WebSocketDataType
}

// MARK: - WebSocket (Message)
struct WebSocketChatData: Codable {
    struct WebSocketChat: Codable {
        let thread: String
        let no: Int
        let vpos: Int
        let date: Int
        let dateUsec: Int
        let mail: String?
        let userId: String
        let premium: Int?
        let anonymity: Int?
        let content: String
    }

    let chat: WebSocketChat
}
