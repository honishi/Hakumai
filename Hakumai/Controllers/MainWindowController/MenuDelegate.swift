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
    @IBOutlet weak var addToMuteUserMenuItem: NSMenuItem!
    @IBOutlet weak var reportAsNgUserMenuItem: NSMenuItem!
    @IBOutlet weak var openUserPageMenuItem: NSMenuItem!
    
    // MARK: General Properties
    let log = XCGLogger.defaultInstance()

    // MARK: Computed Properties
    var tableView: NSTableView {
        return MainViewController.sharedInstance.tableView
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
        case self.copyCommentMenuItem, self.addToMuteUserMenuItem, self.reportAsNgUserMenuItem:
            return true
        case self.copyUrlMenuItem:
            return self.urlStringInComment(chat) != nil ? true : false
        case self.openUserPageMenuItem:
            let isRawId = NicoUtility.sharedInstance.isRawUserId(chat.userId!)
            let isUserComment = (chat.premium == .Ippan || chat.premium == .Premium || chat.premium == .BSP)
            return (isRawId && isUserComment) ? true : false
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
    
    @IBAction func addToMuteUser(sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[self.tableView.clickedRow].chat!
        
        let defaults = NSUserDefaults.standardUserDefaults()
        var muteUserIds = defaults.objectForKey(Parameters.MuteUserIds) as [[String: String]]
        
        for muteUserId in muteUserIds {
            if chat.userId == muteUserId[Parameters.MuteUserIdKeyUserId] {
                log.debug("mute userid [\(chat.userId)] already registered, so skip")
                return
            }
        }
        
        muteUserIds.append([Parameters.MuteUserIdKeyUserId: chat.userId!])
        defaults.setObject(muteUserIds, forKey: Parameters.MuteUserIds)
        defaults.synchronize()
    }
    
    @IBAction func reportAsNgUser(sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[self.tableView.clickedRow].chat!
        NicoUtility.sharedInstance.reportAsNgUser(chat)
    }
    
    @IBAction func openUserPage(sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[self.tableView.clickedRow].chat!
        let userPageUrlString = NicoUtility.sharedInstance.urlStringForUserId(chat.userId!)
        
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: userPageUrlString)!)
    }
    
    // MARK: - Internal Functions
    func urlStringInComment(chat: Chat) -> String? {
        if chat.comment == nil {
            return nil
        }
        
        return chat.comment!.extractRegexpPattern("(https?://[\\w/:%#\\$&\\?\\(\\)~\\.=\\+\\-]+)")
    }
    
    func copyStringToPasteBoard(string: String) -> Bool {
        let pasteBoard = NSPasteboard.generalPasteboard()
        pasteBoard.declareTypes([NSStringPboardType], owner: nil)
        let result = pasteBoard.setString(string, forType: NSStringPboardType)
        log.debug("copied \(string) w/ result \(result)")
        
        return result
    }
}