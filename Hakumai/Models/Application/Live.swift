//
//  Live.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let liveBaseUrl = "http://live.nicovideo.jp/watch/"

struct Live {
    // MARK: - Properties
    // "lv" prefix is included in live id like "lv12345"
    let liveProgramId: String
    let title: String
    let baseTime: Date
    let openTime: Date
    let beginTime: Date
    let isTimeShift: Bool
    let programProvider: ProgramProvider

    var liveUrlString: String { liveBaseUrl + liveProgramId }
}

extension Live: CustomStringConvertible {
    var description: String {
        "Live: liveId[\(liveProgramId)] title[\(title)] " +
            "baseTime[\(baseTime.description)] openTime[\(openTime.description)] " +
            "beginTime[\(beginTime.description)] isTimeShift[\(isTimeShift)] " +
            "programProvider[\(programProvider)]"
    }
}
