//
//  SystemMessage.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/1/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class SystemMessage {
    let message: String
    let date: NSDate
    
    init(message: String) {
        self.message = message
        self.date = NSDate()
    }
}