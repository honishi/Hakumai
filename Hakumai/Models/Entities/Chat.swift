//
//  Chat.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// regular expression
private let kRegexpSeatNo = "/hb ifseetno (\\d+)"

class Chat: CustomStringConvertible {
    var internalNo: Int?
    var roomPosition: RoomPosition?
    var no: Int?
    var date: Date?
    var dateUsec: Int?
    var mail = [String]()
    var userId: String?
    var premium: Premium?
    var comment: String?
    var score: Int?

    var isRawUserId: Bool {
        return Chat.isRawUserId(userId)
    }

    var isUserComment: Bool {
        return Chat.isUserComment(premium)
    }

    var isBSPComment: Bool {
        return Chat.isBSPComment(premium)
    }

    var isSystemComment: Bool {
        return Chat.isSystemComment(premium)
    }

    var kickOutSeatNo: Int? {
        guard let seatNo = comment?.extractRegexp(pattern: kRegexpSeatNo) else {
            return nil
        }
        return Int(seatNo)
    }

    var description: String {
        return (
            "Chat: internalNo[\(internalNo ?? 0)] roomPosition[\(roomPosition?.description ?? "")] no[\(no ?? 0)] " +
                "date[\(date?.description ?? "")] dateUsec[\(dateUsec ?? 0)] mail[\(mail)] userId[\(userId ?? "")] " +
            "premium[\(premium?.description ?? "")] comment[\(comment ?? "")] score[\(score ?? 0)]"
        )
    }

    // MARK: - Object Lifecycle
    init() {
        // nop
    }

    // MARK: - Public Functions
    static func isRawUserId(_ userId: String?) -> Bool {
        guard let userId = userId else {
            return false
        }

        let regexp = try! NSRegularExpression(pattern: "^\\d+$", options: [])
        let matched = regexp.firstMatch(in: userId, options: [], range: NSRange(location: 0, length: userId.utf16.count))

        return matched != nil ? true : false
    }

    static func isUserComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else {
            return false
        }

        return premium == .ippan || premium == .premium
    }

    static func isBSPComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else {
            return false
        }

        return premium == .bsp
    }

    static func isSystemComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else {
            return false
        }

        return premium == .system || premium == .caster || premium == .operator
    }
}
