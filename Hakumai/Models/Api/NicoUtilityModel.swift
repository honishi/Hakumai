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
        let serverTime: Int
        let relive: Relive
    }

    struct Relive: Codable {
        let webSocketUrl: String
    }

    struct Program: Codable {
        let nicoliveProgramId: String
        let title: String
        let thumbnail: Thumbnail
        let openTime: Int
        let beginTime: Int
        let vposBaseTime: Int
        let endTime: Int
        let scheduledEndTime: Int
        let status: String
        let description: String
        let statistics: Statistics
    }

    struct Thumbnail: Codable {
        let small: String
    }

    struct Statistics: Codable {
        let watchCount: Int
        let commentCount: Int
    }

    struct SocialGroup: Codable {
        let type: String
        let id: String
        let description: String
        let name: String
        let thumbnailImageUrl: String
        let thumbnailSmallImageUrl: String
        let level: Int?
    }

    struct EmbeddedDataUser: Codable {
        let id: String
        let nickname: String
    }

    let site: Site
    let program: Program
    let socialGroup: SocialGroup
    let user: EmbeddedDataUser
}

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
