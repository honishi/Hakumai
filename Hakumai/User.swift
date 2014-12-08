//
//  User.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class User: Printable {
    var userId: Int?
    var nickname: String?
    var isPremium: Int?
    var roomLabel: String?
    var seatNo: Int?
    
    var description: String {
        return (
            "User: userId[\(self.userId)] nickname[\(self.nickname)] isPremium[\(self.isPremium)] " +
            "roomLabel[\(self.roomLabel)] seatNo[\(self.seatNo)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}