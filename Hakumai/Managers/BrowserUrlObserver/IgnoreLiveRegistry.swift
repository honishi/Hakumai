//
//  IgnoreUrlRegistry.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/10.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class IgnoreLiveRegistry {
    struct IgnoreLive {
        let untilDate: Date
        let liveProgramId: String
    }

    private var ignoreLives: [IgnoreLive] = []
}

extension IgnoreLiveRegistry: IgnoreLiveRegistryType {
    func add(liveProgramId: String, seconds: TimeInterval) {
        refresh()
        ignoreLives.append(
            IgnoreLive(
                untilDate: Date().addingTimeInterval(seconds),
                liveProgramId: liveProgramId
            )
        )
    }

    func shouldIgnore(liveProgramId: String) -> Bool {
        refresh()
        return ignoreLives.map({ $0.liveProgramId }).contains(liveProgramId)
    }
}

private extension IgnoreLiveRegistry {
    func refresh() {
        let origin = Date()
        ignoreLives = ignoreLives
            .filter { $0.untilDate.timeIntervalSince(origin) > 0 }
        // log.debug(ignoreLives)
    }
}
