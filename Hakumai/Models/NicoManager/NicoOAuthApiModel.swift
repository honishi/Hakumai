//
//  NicoOAuthApiModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/06/06.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct MetaResponse: Codable {
    let status: Int
    let errorCode: String
}

struct WatchProgramsResponse: Codable {
    struct Data: Codable {
        let program: Program
        let socialGroup: SocialGroup
    }

    enum ProgramStatus: String, Codable {
        case onAir = "ON_AIR"
        case ended = "ENDED"
    }

    struct Schedule: Codable {
        let beginTime: Date
        let endTime: Date
        let openTime: Date
        let scheduledEndTime: Date
        let status: ProgramStatus?
        let vposBaseTime: Date
    }

    struct Program: Codable {
        let title: String
        let description: String
        let schedule: Schedule
    }

    struct SocialGroup: Codable {
        let type: String
        let socialGroupId: String
        let description: String
        let name: String
        let thumbnail: URL
        let thumbnailSmall: URL
        let level: Int?
    }

    let meta: MetaResponse
    let data: Data
}

struct UserInfoResponse: Codable {
    let sub: String
    let nickname: String
    let profile: URL
    let picture: URL
    let gender: String?
    let zoneinfo: String?
    let updatedAt: Int
}

struct WsEndpointResponse: Codable {
    struct Data: Codable {
        let url: URL
    }

    let meta: MetaResponse
    let data: Data
}
