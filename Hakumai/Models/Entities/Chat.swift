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
}