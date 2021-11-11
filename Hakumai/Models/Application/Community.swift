//
//  Community.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// community pattern
private let communityPrefixUser = "^co\\d+"
private let communityPrefixChannel = "^ch\\d+"

struct Community {
    // MARK: - Properties
    let communityId: String
    let title: String
    let level: Int
    let thumbnailUrl: URL?

    var isUser: Bool { communityId.hasRegexp(pattern: communityPrefixUser) }
    var isChannel: Bool { communityId.hasRegexp(pattern: communityPrefixChannel) }
}

extension Community: CustomStringConvertible {
    var description: String {
        "Community: community[\(communityId)] title[\(title)] level[\(level)] " +
            "thumbnailUrl[\(thumbnailUrl?.description ?? "-")]"
    }
}
