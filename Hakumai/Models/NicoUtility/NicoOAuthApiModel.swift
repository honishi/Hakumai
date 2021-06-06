//
//  NicoOAuthApiModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/06/06.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct UserInfoResponse: Codable {
    let sub: String
    let nickname: String
    let profile: URL
    let picture: URL
    let gender: String?
    let zoneinfo: String?
    let updatedAt: Int
}
