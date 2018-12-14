//
//  Live.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kLiveBaseUrl = "http://live.nicovideo.jp/watch/"

class Live: CustomStringConvertible {
    // "lv" prefix is included in live id like "lv12345"
    var liveId: String?
    var title: String?
    var community: Community = Community()
    var baseTime: Date?
    var openTime: Date?
    var startTime: Date?

    var liveUrlString: String {
        return kLiveBaseUrl + (liveId ?? "")
    }

    var description: String {
        return (
            "Live: liveId[\(liveId ?? "")] title[\(title ?? "")] community[\(community)] " +
            "baseTime[\(baseTime?.description ?? "")] openTime[\(openTime?.description ?? "")] startTime[\(startTime?.description ?? "")]"
        )
    }

    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}
