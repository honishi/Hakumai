//
//  ChatContainer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// thread safe chat container
class ChatContainer {
    var chats: [Chat] = []
    
    class var sharedContainer : ChatContainer {
        struct Static {
            static let instance = ChatContainer()
        }
        return Static.instance
    }
    
    func append(chat: Chat) -> Int {
        objc_sync_enter(self)
        self.chats.append(chat)
        let count = self.chats.count
        objc_sync_exit(self)
        
        return count
    }
    
    func count() -> Int {
        objc_sync_enter(self)
        let count = self.chats.count
        objc_sync_exit(self)
        
        return count
    }
    
    subscript (index: Int) -> Chat {
        objc_sync_enter(self)
        let chat = self.chats[index]
        objc_sync_exit(self)
        
        return chat
    }
    
    func removeAll() {
        objc_sync_enter(self)
        self.chats.removeAll(keepCapacity: false)
        objc_sync_exit(self)
    }
}

