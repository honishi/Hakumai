//
//  Chat.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class Chat: Printable {
    var roomPosition: RoomPosition?
    var no: Int?
    var date: NSDate?
    var dateUsec: Int?
    var mail: String?
    var userId: String?
    var premium: Premium?
    var comment: String?
    var score: Int?
    
    var description: String {
        return (
            "Chat: roomPosition[\(self.roomPosition)] no[\(self.no)] date[\(self.date)] " +
            "dateUsec[\(self.dateUsec)] mail[\(self.mail)] userId[\(self.userId)]" +
            "premium[\(self.premium)] comment[\(self.comment)] score[\(self.score)]"
        )
    }
    
    // MARK: - Object Lifecycle
    init() {
        // nop
    }

    // MARK: - Public Functions
    class func isRawUserId(userId: String?) -> Bool {
        if userId == nil {
            return false
        }
        
        let regexp = NSRegularExpression(pattern: "^\\d+$", options: nil, error: nil)!
        let matched = regexp.firstMatchInString(userId!, options: nil, range: NSMakeRange(0, userId!.utf16Count))
        
        return matched != nil ? true : false
    }
    
    func isRawUserId() -> Bool {
        return Chat.isRawUserId(self.userId)
    }
    
    class func isUserComment(premium: Premium?) -> Bool {
        if premium == nil {
            return false
        }
        
        // use explicit unwrapping enum values, instead of implicit unwrapping like "premium == .Ippan"
        // see details at http://stackoverflow.com/a/26204610
        return (premium! == .Ippan || premium! == .Premium || premium! == .BSP)
    }
    
    func isUserComment() -> Bool {
        return Chat.isUserComment(self.premium)
    }
}