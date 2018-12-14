//
//  Community.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// community pattern
private let kCommunityPrefixUser = "^co\\d+"
private let kCommunityPrefixChannel = "^ch\\d+"

class Community: CustomStringConvertible {
    var community: String?
    var title: String? = ""
    var level: Int?
    var thumbnailUrl: URL?

    var isUser: Bool? {
        return community?.hasRegexp(pattern: kCommunityPrefixUser)
    }

    var isChannel: Bool? {
        return community?.hasRegexp(pattern: kCommunityPrefixChannel)
    }

    var description: String {
        return (
            "Community: community[\(community ?? "")] title[\(title ?? "")] level[\(level ?? 0)] " +
            "thumbnailUrl[\(thumbnailUrl?.description ?? "")]"
        )
    }

    // MARK: Object Lifecycle
    init() {
        // nop
    }
}
