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

class Community: Printable {
    var community: String?
    var title: String? = ""
    var level: Int?
    var thumbnailUrl: NSURL?

    var isUser: Bool? {
        return self.community?.hasRegexpPattern(kCommunityPrefixUser)
    }
    
    var isChannel: Bool? {
        return self.community?.hasRegexpPattern(kCommunityPrefixChannel)
    }
    
    var description: String {
        return (
            "Community: community[\(self.community)] title[\(self.title)] level[\(self.level)] " +
            "thumbnailUrl[\(self.thumbnailUrl)]"
        )
    }

    // MARK: Object Lifecycle
    init() {
        // nop
    }
}