//
//  ChatContainer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// thread safe chat container
class MessageContainer {
    var messages = [Message]()
    var firstChat = [String: Bool]()
    var calculatingActive: Bool = false
    
    let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    class var sharedContainer : MessageContainer {
        struct Static {
            static let instance = MessageContainer()
        }
        return Static.instance
    }
    
    // MARK: - Basic Operation to Content Array
    func append(chatOrSystemMessage object: AnyObject) -> Int {
        objc_sync_enter(self)
 
        var message: Message!
        
        if let systemMessage = object as? String {
            message = Message(message: systemMessage)
        }
        else if let chat = object as? Chat {
            var isFirstChat = false
            
            if chat.premium == .Ippan || chat.premium == .Premium {
                isFirstChat = (self.firstChat[chat.userId!] == nil ? true : false)
                if isFirstChat {
                    self.firstChat[chat.userId!] = true
                }
            }
            
            message = Message(chat: chat, firstChat: isFirstChat)
        }
        else {
            assert(false, "appending unexpected object")
        }
        
        self.messages.append(message)
        let count = self.messages.count
        
        objc_sync_exit(self)
        
        return count
    }
    
    func count() -> Int {
        objc_sync_enter(self)
        let count = self.messages.count
        objc_sync_exit(self)
        
        return count
    }
    
    subscript (index: Int) -> Message {
        objc_sync_enter(self)
        let content = self.messages[index]
        objc_sync_exit(self)
        
        return content
    }
    
    func removeAll() {
        objc_sync_enter(self)
        self.messages.removeAll(keepCapacity: false)
        self.firstChat.removeAll(keepCapacity: false)
        objc_sync_exit(self)
    }
    
    // MARK: - Utility
    func calculateActive(completion: (active: Int?) -> (Void)) {
        if self.calculatingActive {
            log.debug("detected duplicate calculating active, so skip.")
            completion(active: nil)
            return
        }
        
        objc_sync_enter(self)
        self.calculatingActive = true
        objc_sync_exit(self)
        
        // log.debug("calcurating active")
        
        // swift way to use background gcd, http://stackoverflow.com/a/25070476
        let qualityOfServiceClass = Int(QOS_CLASS_BACKGROUND.value)
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        
        dispatch_async(backgroundQueue, {
            var activeUsers = Dictionary<String, Bool>()
            let tenMinutesAgo = NSDate(timeIntervalSinceNow: (Double)(-10 * 60))
            
            // self.log.debug("start counting active")
            
            for var i = self.count(); 0 < i ; i-- {
                let message = self[i - 1]
                
                if message.messageType == .System {
                    continue
                }
                
                let chat = message.chat!
                
                if chat.date == nil || chat.userId == nil {
                    continue
                }
                
                // is "chat.date < tenMinutesAgo" ?
                if chat.date!.compare(tenMinutesAgo) == .OrderedAscending {
                    break
                }
                
                activeUsers[chat.userId!] = true
            }
            
            // self.log.debug("end counting active")

            completion(active: activeUsers.count)
            
            objc_sync_enter(self)
            self.calculatingActive = false
            objc_sync_exit(self)
        })
    }
}