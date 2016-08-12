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
        let seatNo = comment?.extractRegexpPattern(kRegexpSeatNo)
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
    class func isRawUserId(_ userId: String?) -> Bool {
        if userId == nil {
            return false
        }
        
        let regexp = try! NSRegularExpression(pattern: "^\\d+$", options: [])
        let matched = regexp.firstMatch(in: userId!, options: [], range: NSMakeRange(0, userId!.utf16.count))
        
        return matched != nil ? true : false
    }
    
    class func isUserComment(_ premium: Premium?) -> Bool {
        if premium == nil {
            return false
        }
        
        // use explicit unwrapping enum values, instead of implicit unwrapping like "premium == .Ippan"
        // see details at http://stackoverflow.com/a/26204610
        return (premium! == .ippan || premium! == .premium)
    }
    
    class func isBSPComment(_ premium: Premium?) -> Bool {
        if premium == nil {
            return false
        }
        
        return (premium! == .bsp)
    }
    
    class func isSystemComment(_ premium: Premium?) -> Bool {
        if premium == nil {
            return false
        }
        
        return (premium! == .system || premium! == .caster || premium! == .operator)
    }
}
