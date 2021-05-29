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

final class Community: CustomStringConvertible {
    var communityId: String
    var title: String
    var level: Int
    var thumbnailUrl: URL?

    var isUser: Bool { communityId.hasRegexp(pattern: communityPrefixUser) }
    var isChannel: Bool { communityId.hasRegexp(pattern: communityPrefixChannel) }

    var description: String {
        return (
            "Community: community[\(communityId)] title[\(title)] level[\(level)] " +
                "thumbnailUrl[\(thumbnailUrl?.description ?? "-")]"
        )
    }

    // MARK: Object Lifecycle
    init(communityId: String, title: String, level: Int, thumbnailUrl: URL?) {
        self.communityId = communityId
        self.title = title
        self.level = level
        self.thumbnailUrl = thumbnailUrl
    }
}
