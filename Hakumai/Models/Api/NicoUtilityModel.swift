//
//  NicoUtilityModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/05.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct EmbeddedDataProperties: Codable {
    struct Site: Codable {
        let relive: Relive
    }

    struct Relive: Codable {
        let webSocketUrl: String
    }

    let site: Site
}
