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
        let seatNo = comment?.extractRegexp(pattern: kRegexpSeatNo)
        return seatNo == nil ? nil : Int(seatNo!)
    }
    
    var description: String {
        return (
            "Chat: internalNo[\(internalNo)] roomPosition[\(roomPosition)] no[\(no)] " +
            "date[\(date)] dateUsec[\(dateUsec)] mail[\(mail)] userId[\(userId)] " +
            "premium[\(premium)] comment[\(comment)] score[\(score)]"
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
        let matched = regexp.firstMatch(in: userId, options: [], range: NSMakeRange(0, userId.utf16.count))
        
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
