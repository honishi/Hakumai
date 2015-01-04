//
//  HandleNameManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

// handle name manager
class HandleNameManager {
    // MARK: - Properties
    // userId: HandleName
    private var handleNames = [String: String]()
    
    private let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    class var sharedManager : HandleNameManager {
        struct Static {
            static let instance = HandleNameManager()
        }
        return Static.instance
    }

    // MARK: - [Super Class] Overrides
    // MARK: - [Protocol] Functions
    
    // MARK: - Public Functions
    func extractAndUpdateHandleNameWithChat(chat: Chat) {
        if chat.userId == nil || chat.comment == nil {
            return
        }
        
        if let handleName = self.extractHandleNameFromComment(chat.comment!) {
            self.updateHandleNameWithChat(chat, handleName: handleName)
        }
    }
    
    func updateHandleNameWithChat(chat: Chat, handleName: String) {
        if chat.userId == nil {
            return
        }
        
        objc_sync_enter(self)
        self.handleNames[chat.userId!] = handleName
        objc_sync_exit(self)
    }
    
    func removeHandleNameWithChat(chat: Chat) {
        if chat.userId == nil {
            return
        }
        
        objc_sync_enter(self)
        self.handleNames.removeValueForKey(chat.userId!)
        objc_sync_exit(self)
    }
    
    func handleNameForChat(chat: Chat) -> String? {
        if chat.userId == nil {
            return nil
        }
        
        objc_sync_enter(self)
        let handleName = self.handleNames[chat.userId!]
        objc_sync_exit(self)
        
        return handleName
    }
    
    // MARK: - Internal Functions
    func extractHandleNameFromComment(comment: String) -> String? {
        let handleName = comment.extractRegexpPattern(".*[@＠]\\s*(\\S{2,})\\s*")
        return handleName
    }
}
