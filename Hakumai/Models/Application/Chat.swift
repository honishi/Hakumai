//
//  Chat.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct Chat {
    // MARK: - Properties
    let roomPosition: RoomPosition
    let no: Int
    let date: Date
    let dateUsec: Int
    let mail: [String]?
    let userId: String
    let comment: String
    let premium: Premium
}

extension Chat: CustomStringConvertible {
    var description: String {
        "Chat: roomPosition[\(roomPosition)] no[\(no)] " +
            "date[\(date.description)] dateUsec[\(dateUsec)] mail[\(mail ?? [])] userId[\(userId)] " +
            "premium[\(premium.description)] comment[\(comment)]"
    }
}
