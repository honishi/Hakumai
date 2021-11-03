//
//  NicoRestApiModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/05.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MARK: - Rest API
struct UserNickname: Codable {
    struct Data: Codable {
        let id: String
        let nickname: String
    }

    let data: Data
}
