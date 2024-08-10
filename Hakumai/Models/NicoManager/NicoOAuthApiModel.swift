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
    let errorCode: String?
}

struct WatchProgramsResponse: Codable {
    struct Data: Codable {
        let program: Program
        let programProvider: ProgramProvider
    }

    enum ProgramStatus: String, Codable {
        // https://github.com/niconamaworkshop/api/blob/master/oauth/watch/_program.md
        case beforeRelease = "BEFORE_RELEASE"
        case released = "RELEASED"
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

    // https://github.com/niconamaworkshop/api/blob/master/oauth/watch/_programProvider.md
    struct ProgramProvider: Codable {
        let name: String
        let profileUrl: URL
        let programProviderId: String
        let type: String
        let userLevel: Int?
        let icons: Icons

        // swiftlint:disable nesting
        struct Icons: Codable {
            let uri150x150: URL
            let uri50x50: URL
        }
        // swiftlint:enable nesting
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
