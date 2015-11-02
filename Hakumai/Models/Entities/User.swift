//
//  User.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kRoomLabelForArena = "c[oh]\\d+"
private let kRoomLabelForBSP = "バックステージパス"

class User: CustomStringConvertible {
    var userId: Int?
    var nickname: String?
    var isPremium: Int?
    var roomLabel: String?
    var seatNo: Int?
    
    var isArena: Bool? {
        return self.roomLabel?.hasRegexpPattern(kRoomLabelForArena)
    }

    var isBSP: Bool? {
        return self.roomLabel?.hasRegexpPattern(kRoomLabelForBSP)
    }

    var description: String {
        return (
            "User: userId[\(self.userId)] nickname[\(self.nickname)] isPremium[\(self.isPremium)] " +
            "roomLabel[\(self.roomLabel)] seatNo[\(self.seatNo)] isArena[\(self.isArena)] isBSP[\(self.isBSP)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}