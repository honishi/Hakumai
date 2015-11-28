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
        return roomLabel?.hasRegexpPattern(kRoomLabelForArena)
    }

    var isBSP: Bool? {
        return roomLabel?.hasRegexpPattern(kRoomLabelForBSP)
    }

    var description: String {
        return (
            "User: userId[\(userId)] nickname[\(nickname)] isPremium[\(isPremium)] " +
            "roomLabel[\(roomLabel)] seatNo[\(seatNo)] isArena[\(isArena)] isBSP[\(isBSP)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }
}