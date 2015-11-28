//
//  Thread.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class Thread: CustomStringConvertible {
    var resultCode: Int?
    var thread: Int?
    var lastRes: Int? = 0
    var ticket: String?
    var serverTime: NSDate?
    
    var description: String {
        return (
            "Thread: resultCode[\(resultCode)] thread[\(thread)] lastRes[\(lastRes)] " +
            "ticket[\(ticket)] serverTime[\(serverTime)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}