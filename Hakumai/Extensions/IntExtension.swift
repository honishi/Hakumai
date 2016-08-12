//
//  IntExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/8/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

extension Int {
    func toDateAsTimeIntervalSince1970() -> Date {
        return Date(timeIntervalSince1970: Double(self))
    }
}
