//
//  MenuDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/4/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCGLogger

class MenuDelegate: NSObject, NSMenuDelegate {
    // MARK: Menu Outlets
    @IBOutlet weak var copyCommentMenuItem: NSMenuItem!
    @IBOutlet weak var copyUrlMenuItem: NSMenuItem!

    // MARK: General Properties
    let log = XCGLogger.defaultInstance()

    // MARK: Computed Properties
    var tableView: NSTableView {
        return MainViewController.instance()!.tableView
    }
    
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // MARK: - NSMenu Overrides
    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        let clickedRow = self.tableView.clickedRow
        if clickedRow == -1 {
            return false
        }
        
        let message = MessageContainer.sharedContainer[clickedRow]
        if message.messageType != .Chat {
            return false
        }
        
        let chat = message.chat!
        
        switch menuItem {
        case self.copyCommentMenuItem:
            return true
        case self.copyUrlMenuItem:
            return self.urlStringInComment(chat) != nil ? true : false
        default:
            break
        }
        
        return false
    }

    // MARK: - NSMenuDelegate Functions
    func menuWillOpen(menu: NSMenu) {
        self.resetMenu()
        
        let clickedRow = self.tableView.clickedRow
        if clickedRow == -1 {
            return
        }
        
        let message = MessageContainer.sharedContainer[clickedRow]
        
        if message.messageType != .Chat {
            return
        }
        
        self.configureMenu(message.chat!)
    }
    
    // MARK: Utility
    func resetMenu() {
    }
    
    func configureMenu(chat: Chat) {
    }

    // MARK: - Context Menu Handlers
    @IBAction func copyComment(sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[self.tableView.clickedRow].chat!
        let toBeCopied = chat.comment!
        self.copyStringToPasteBoard(toBeCopied)
    }
    
    @IBAction func copyUrl(sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[self.tableView.clickedRow].chat!
        let toBeCopied = self.urlStringInComment(chat)!
        self.copyStringToPasteBoard(toBeCopied)
    }
    
    // MARK: - Internal Functions
    func urlStringInComment(chat: Chat) -> String? {
        if chat.comment == nil {
            return nil
        }
        
        return chat.comment!.extractRegexpPattern("(https?://[\\w/:%#\\$&\\?\\(\\)~\\.=\\+\\-]+)", index: 0)
    }
    
    func copyStringToPasteBoard(string: String) -> Bool {
        let pasteBoard = NSPasteboard.generalPasteboard()
        pasteBoard.declareTypes([NSStringPboardType], owner: nil)
        let result = pasteBoard.setString(string, forType: NSStringPboardType)
        log.debug("copied \(string) w/ result \(result)")
        
        return result
    }
}