//
//  ChatContainer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// thread safe chat container
class MessageContainer {
    // MARK: - Properties
    // MARK: Public
    static let sharedContainer = MessageContainer()

    var beginDateToShowHbIfseetnoCommands: NSDate?
    var showHbIfseetnoCommands = false
    var enableMuteUserIds = false
    var muteUserIds = [[String: String]]()
    var enableMuteWords = false
    var muteWords = [[String: String]]()
    
    // MARK: Private
    private var sourceMessages = [Message]()
    private var filteredMessages = [Message]()

    private var firstChat = [String: Bool]()
    
    private var rebuildingFilteredMessages = false
    private var calculatingActive = false
    
    // MARK: - Basic Operation to Content Array
    func append(chatOrSystemMessage object: AnyObject) -> (appended: Bool, count: Int) {
        objc_sync_enter(self)
 
        var message: Message!
        
        if let systemMessage = object as? String {
            message = Message(message: systemMessage)
        }
        else if let chat = object as? Chat {
            var isFirstChat = false
            
            if chat.isUserComment {
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
            logger.debug("detected rebuilding filtered messages, so skip calculating active.")
            completion(active: nil)
            return
        }
        
        if self.calculatingActive {
            logger.debug("detected duplicate calculating, so skip calculating active.")
            completion(active: nil)
            return
        }
        
        objc_sync_enter(self)
        self.calculatingActive = true
        objc_sync_exit(self)
        
        // logger.debug("calcurating active")
        
        // swift way to use background gcd, http://stackoverflow.com/a/25070476
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
            var activeUsers = Dictionary<String, Bool>()
            let tenMinutesAgo = NSDate(timeIntervalSinceNow: (Double)(-10 * 60))
            
            // logger.debug("start counting active")
            
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
                
                if !chat.isUserComment {
                    continue
                }
                
                // is "chat.date < tenMinutesAgo" ?
                if chat.date!.compare(tenMinutesAgo) == .OrderedAscending {
                    break
                }
                
                activeUsers[chat.userId!] = true
            }
            
            // logger.debug("end counting active")
            
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
            // logger.debug("started 1st pass rebuilding filtered messages (bg section)")
            
            var workingMessages = [Message]()
            let sourceCount = self.sourceMessages.count
            
            for i in 0..<sourceCount {
                self.appendMessage(self.sourceMessages[i], messages: &workingMessages)
            }
            
            // logger.debug("completed 1st pass")
            
            // 2nd pass:
            // we need to replace old filtered messages with new one with the following conditions;
            // - exclusive to ui updates, so use main thread
            // - atomic to any other operation like append, count, calcurate and so on, so use objc_sync_enter/exit
            dispatch_async(dispatch_get_main_queue(), {
                // logger.debug("started 2nd pass rebuilding filtered messages (critical section)")
                
                objc_sync_enter(self)
                self.rebuildingFilteredMessages = true
                
                self.filteredMessages = workingMessages
                // logger.debug("copied working messages to filtered messages")
                
                let deltaCount = self.sourceMessages.count
                for i in sourceCount..<deltaCount {
                    self.appendMessage(self.sourceMessages[i], messages: &self.filteredMessages)
                }
                // logger.debug("copied delta messages \(sourceCount)..<\(deltaCount)")
                
                self.rebuildingFilteredMessages = false
                objc_sync_exit(self)
                
                // logger.debug("completed 2nd pass")
                logger.debug("completed to rebuild filtered messages")
                
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
        // filter by message type
        if message.messageType == .System {
            return true
        }
        
        let chat = message.chat!

        // filter by comment
        if let comment = chat.comment {
            if comment.hasPrefix("/hb ifseetno ") {
                if self.showHbIfseetnoCommands == false {
                    return false
                }

                // kickout commands should be ignored before live starts. espacially in channel live,
                // there are tons of kickout commands. and they forces application performance to be slowed down.
                if chat.date != nil && self.beginDateToShowHbIfseetnoCommands != nil {
                    // chat.date < self.beginDateToShowHbIfseetnoCommands
                    if chat.date!.compare(self.beginDateToShowHbIfseetnoCommands!) == .OrderedAscending {
                        return false
                    }
                }
            }
            
            if self.enableMuteWords {
                for muteWord in self.muteWords {
                    if let word = muteWord[MuteUserWordKey.Word] {
                        if comment.lowercaseString.rangeOfString(word.lowercaseString) != nil {
                            return false
                        }
                    }
                }
            }
        }
        
        // filter by userid
        if let userId = chat.userId {
            if self.enableMuteUserIds {
                for muteUserId in self.muteUserIds {
                    if muteUserId[MuteUserIdKey.UserId] == userId {
                        return false
                    }
                }
            }
        }
        
        return true
    }
}