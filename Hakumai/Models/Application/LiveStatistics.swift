//
//  Heatbeat.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/8/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class LiveStatistics {
    // MARK: - Properties
    let viewers: Int
    let comments: Int
    let adPoints: Int?
    let giftPoints: Int?

    // MARK: - Object Lifecycle
    init(viewers: Int, comments: Int, adPoints: Int?, giftPoints: Int?) {
        self.viewers = viewers
        self.comments = comments
        self.adPoints = adPoints
        self.giftPoints = giftPoints
    }
}
