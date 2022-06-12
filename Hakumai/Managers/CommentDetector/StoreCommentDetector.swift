//
//  StoreCommentDetector.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/13.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let ignoreSecondsSinceLastDetection: TimeInterval = 3

final class StoreCommentDetector {
    private var lastDetectionDate = Date()
}

extension StoreCommentDetector: StoreCommentDetectorType {
    func isStoreComment(chat: Chat) -> Bool {
        let now = Date()
        let elapsedEnoughTime = now.timeIntervalSince(lastDetectionDate) > ignoreSecondsSinceLastDetection
        // log.debug("\(elapsedEnoughTime), \(now.timeIntervalSince(lastDetectionDate))")
        guard elapsedEnoughTime else { return false }
        if chat.roomPosition == .arena {
            return false
        }
        lastDetectionDate = now
        return true
    }
}
