//
//  Live.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let liveBaseUrl = "http://live.nicovideo.jp/watch/"

final class Live: CustomStringConvertible {
    // "lv" prefix is included in live id like "lv12345"
    let liveId: String
    let title: String
    let community: Community?
    let baseTime: Date
    let openTime: Date
    let beginTime: Date

    var liveUrlString: String { liveBaseUrl + liveId }

    var description: String {
        return (
            "Live: liveId[\(liveId)] title[\(title)] community[\(community?.description ?? "-")] " +
                "baseTime[\(baseTime.description)] openTime[\(openTime.description)] beginTime[\(beginTime.description)]"
        )
    }

    // MARK: - Object Lifecycle
    init(liveId: String, title: String, community: Community?, baseTime: Date, openTime: Date, beginTime: Date) {
        self.liveId = liveId
        self.title = title
        self.community = community
        self.baseTime = baseTime
        self.openTime = openTime
        self.beginTime = beginTime
    }
}
