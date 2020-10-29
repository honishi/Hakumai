//
//  Thread.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class Thread: CustomStringConvertible {
    var resultCode: Int?
    var thread: Int?
    var lastRes: Int? = 0
    var ticket: String?
    var serverTime: Date?

    var description: String {
        return (
            "Thread: resultCode[\(resultCode ?? 0)] thread[\(thread ?? 0)] lastRes[\(lastRes ?? 0)] " +
                "ticket[\(ticket ?? "")] serverTime[\(serverTime?.description ?? "")]"
        )
    }

    // MARK: - Object Lifecycle
    init() {}
}
