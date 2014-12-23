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
    // MARK: - Properties
    // MARK: Public
    var showHbIfseetnoCommands = false
    
    // MARK: Private
    private var sourceMessages = [Message]()
    private var filteredMessages = [Message]()

    private var firstChat = [String: Bool]()
    
    private var rebuildingFilteredMessages: Bool = false
    private var calculatingActive: Bool = false
    
    private let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    class var sharedContainer : MessageContainer {
        struct Static {
            static let instance = MessageContainer()
        }
        return Static.instance
    }
    
    // MARK: - Basic Operation to Content Array
    func append(chatOrSystemMessage object: AnyObject) -> (appended: Bool, count: Int) {
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
        
        self.sourceMessages.append(message)

        let appended = self.appendMessage(message, messages: &self.filteredMessages)
        let count = self.filteredMessages.count
        
        objc_sync_exit(self)
        
        return (appended, count)
    }
    
    func count() -> Int {
        objc_sync_enter(self)
        let count = self.filteredMessages.count
        objc_sync_exit(self)
        
        return count
    }
    
    subscript (index: Int) -> Message {
        objc_sync_enter(self)
        let content = self.filteredMessages[index]
        objc_sync_exit(self)
        
        return content
    }
    
    func messagesWithUserId(userId: String) -> [Message] {
        var userMessages = [Message]()
        
        objc_sync_enter(self)
        for message in sourceMessages {
            if message.messageType != .Chat {
                continue
            }
            
            if message.chat?.userId == userId {
                userMessages.append(message)
            }
        }
        objc_sync_exit(self)
        
        return userMessages
    }
    
    func removeAll() {
        objc_sync_enter(self)
        self.sourceMessages.removeAll(keepCapacity: false)
        self.filteredMessages.removeAll(keepCapacity: false)
        self.firstChat.removeAll(keepCapacity: false)
        Message.resetMessageNo()
        objc_sync_exit(self)
    }
    
    // MARK: - Utility
    func calculateActive(completion: (active: Int?) -> (Void)) {
        if self.rebuildingFilteredMessages {
            log.debug("detected rebuilding filtered messages, so skip calculating active.")
            completion(active: nil)
            return
        }
        
        if self.calculatingActive {
            log.debug("detected duplicate calculating, so skip calculating active.")
            completion(active: nil)
            return
        }
        
        objc_sync_enter(self)
        self.calculatingActive = true
        objc_sync_exit(self)
        
        // log.debug("calcurating active")
        
        // swift way to use background gcd, http://stackoverflow.com/a/25070476
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
            var activeUsers = Dictionary<String, Bool>()
            let tenMinutesAgo = NSDate(timeIntervalSinceNow: (Double)(-10 * 60))
            
            // self.log.debug("start counting active")
            
            objc_sync_enter(self)
            let count = self.sourceMessages.count
            objc_sync_exit(self)
            
            for var i = count; 0 < i ; i-- {
                objc_sync_enter(self)
                let message = self.sourceMessages[i - 1]
                objc_sync_exit(self)
                
                if message.messageType == .System {
                    continue
                }
                
                let chat = message.chat!
                
                if chat.date == nil || chat.userId == nil {
                    continue
                }
                
                if !(chat.premium == .Ippan || chat.premium == .Premium) {
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
    
    // MARK: - Internal Functions
    func rebuildFilteredMessages(completion: () -> Void) {
        // 1st pass:
        // copy and filter source messages. this could be long operation so use background thread
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
            self.log.debug("started 1st pass rebuilding filtered messages (bg section)")
            
            var workingMessages = [Message]()
            let sourceCount = self.sourceMessages.count
            
            for i in 0..<sourceCount {
                self.appendMessage(self.sourceMessages[i], messages: &workingMessages)
            }
            
            self.log.debug("completed 1st pass")
            
            // 2nd pass:
            // we need to replace old filtered messages with new one with the following conditions;
            // - exclusive to ui updates, so use main thread
            // - atomic to any other operation like append, count, calcurate and so on, so use objc_sync_enter/exit
            dispatch_async(dispatch_get_main_queue(), {
                self.log.debug("started 2nd pass rebuilding filtered messages (crytical section)")
                
                objc_sync_enter(self)
                self.rebuildingFilteredMessages = true
                
                self.filteredMessages = workingMessages
                self.log.debug("copied working messages to filtered messages")
                
                let deltaCount = self.sourceMessages.count
                for i in sourceCount..<deltaCount {
                    self.appendMessage(self.sourceMessages[i], messages: &self.filteredMessages)
                }
                self.log.debug("copied delta messages \(sourceCount)..<\(deltaCount)")
                
                self.rebuildingFilteredMessages = false
                objc_sync_exit(self)
                
                self.log.debug("completed 2nd pass")
                
                // completion
                completion()
            })
        })
    }
    
    // MARK: Filtered Message Append Utility
    func appendMessage(message: Message, inout messages: [Message]) -> Bool {
        var appended = false
        
        if self.shouldAppendMessage(message) {
            messages.append(message)
            appended = true
        }
        
        return appended
    }

    func shouldAppendMessage(message: Message) -> Bool {
        if message.messageType == .System {
            return true
        }
        
        let chat = message.chat!

        if (chat.premium == .System || chat.premium == .Operator || chat.premium == .BSP) &&
            chat.roomPosition != .Arena {
            return false
        }

        if self.showHbIfseetnoCommands == false {
            if chat.comment?.hasPrefix("/hb ifseetno ") == true {
                // log.debug("filtered: \(chat.comment!)")
                return false
            }
        }
        
        return true
    }
}