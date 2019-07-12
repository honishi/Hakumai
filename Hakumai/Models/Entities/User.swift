//
//  User.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kRoomLabelForArena = "c[oh]\\d+"
private let kRoomLabelForArenaOffical = "アリーナ"
private let kRoomLabelForBSP = "バックステージパス"

final class User: CustomStringConvertible {
    var userId: Int?
    var nickname: String?
    var isPremium: Int?
    var roomLabel: String?
    var seatNo: Int?

    var isArena: Bool? {
        return roomLabel?.hasRegexp(pattern: kRoomLabelForArena) == true ? true : roomLabel?.hasRegexp(pattern: kRoomLabelForArenaOffical)
    }

    var isBSP: Bool? {
        return roomLabel?.hasRegexp(pattern: kRoomLabelForBSP)
    }

    var description: String {
        return (
            "User: userId[\(userId ?? 0)] nickname[\(nickname ?? "")] isPremium[\(isPremium ?? 0)] " +
            "roomLabel[\(roomLabel ?? "")] seatNo[\(seatNo ?? 0)] isArena[\(isArena ?? false)] isBSP[\(isBSP ?? false)]"
        )
    }

    // MARK: - Object Lifecycle
    init() {}
}
