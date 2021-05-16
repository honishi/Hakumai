//
//  NicoWebModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/16.
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
