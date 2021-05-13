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

final class Chat: CustomStringConvertible {
    let roomPosition: RoomPosition = .arena
    let no: Int
    let date: Date
    let dateUsec: Int
    let mail: [String]?
    let userId: String
    let comment: String
    let premium: Premium
    let score: Int? = 0

    var isRawUserId: Bool { return Chat.isRawUserId(userId) }
    var isUserComment: Bool { return Chat.isUserComment(premium) }
    var isBSPComment: Bool { return Chat.isBSPComment(premium) }
    var isSystemComment: Bool { return Chat.isSystemComment(premium) }

    var kickOutSeatNo: Int? {
        guard let seatNo = comment.extractRegexp(pattern: kRegexpSeatNo) else { return nil }
        return Int(seatNo)
    }

    var description: String {
        return (
            "Chat: roomPosition[\(roomPosition.description)] no[\(no)] " +
                "date[\(date.description)] dateUsec[\(dateUsec)] mail[\(mail ?? [])] userId[\(userId)] " +
                "premium[\(premium.description)] comment[\(comment)]"
        )
    }

    // MARK: - Object Lifecycle
    init(no: Int, date: Date, dateUsec: Int, mail: [String]?, userId: String, comment: String, premium: Premium) {
        self.no = no
        self.date = date
        self.dateUsec = dateUsec
        self.mail = mail
        self.userId = userId
        self.comment = comment
        self.premium = premium
    }
}

// MARK: - Public Functions
extension Chat {
    static func isRawUserId(_ userId: String?) -> Bool {
        guard let regexp = try? NSRegularExpression(pattern: "^\\d+$", options: []),
              let userId = userId else { return false }
        let matched = regexp.firstMatch(
            in: userId,
            options: [],
            range: NSRange(location: 0, length: userId.utf16.count))
        return matched != nil
    }

    static func isUserComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else { return false }
        return premium == .ippan || premium == .premium || premium == .ippanTransparent
    }

    static func isBSPComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else { return false }
        return premium == .bsp
    }

    static func isSystemComment(_ premium: Premium?) -> Bool {
        guard let premium = premium else { return false }
        return premium == .system || premium == .caster || premium == .operator
    }
}
