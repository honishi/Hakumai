//
//  NicoWebSocketModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/16.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - WebSocket (Watch, Generic Model)
enum WebSocketDataType: String, Codable {
    case ping, seat, messageServer, statistics, disconnect, reconnect
}

struct WebSocketData: Codable {
    let type: WebSocketDataType
}

// MARK: - WebSocket (Watch, Specific Model)
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

// {"type":"messageServer","data":{"viewUri":"https://mpn.live.nicovideo.jp/api/view/v4/BBzh6D87sTyygFaji0QUuxYWeJbYqgeRcbK7DumuGq4bnH4mCSWhNCjr_Y2D6X6ksyGVx9swrDbd","vposBaseTime":"2024-08-05T17:00:00+09:00","hashedUserId":"a:U5xlhzXQVY6YzMW1"}}
struct WebSocketMessageServerData: Codable {
    struct Data: Codable {
        let viewUri: String
        let vposBaseTime: String
        let hashedUserId: String
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

struct WebSocketReconnectData: Codable {
    struct Data: Codable {
        let audienceToken: String
        let waitTimeSec: Int
    }

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

struct WebSocketPingContentData: Codable {
    struct Ping: Codable {
        let content: String
    }

    let ping: Ping
}
