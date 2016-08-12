//
//  MenuDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/4/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class MenuDelegate: NSObject, NSMenuDelegate, NSSharingServiceDelegate {
    // MARK: Menu Outlets
    @IBOutlet weak var copyCommentMenuItem: NSMenuItem!
    @IBOutlet weak var openUrlMenuItem: NSMenuItem!
    @IBOutlet weak var tweetCommentMenuItem: NSMenuItem!
    @IBOutlet weak var addHandleNameMenuItem: NSMenuItem!
    @IBOutlet weak var removeHandleNameMenuItem: NSMenuItem!
    @IBOutlet weak var addToMuteUserMenuItem: NSMenuItem!
    @IBOutlet weak var reportAsNgUserMenuItem: NSMenuItem!
    @IBOutlet weak var openUserPageMenuItem: NSMenuItem!
    
    // MARK: Computed Properties
    var tableView: NSTableView {
        return MainViewController.sharedInstance.tableView
    }
    
    var live: Live? {
        return MainViewController.sharedInstance.live
    }
    
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // MARK: - NSMenu Overrides
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let clickedRow = tableView.clickedRow
        if clickedRow == -1 {
            return false
        }
        
        let message = MessageContainer.sharedContainer[clickedRow]
        if message.messageType != .chat {
            return false
        }
        
        let chat = message.chat!
        
        switch menuItem {
        case copyCommentMenuItem, tweetCommentMenuItem:
            return true
        case openUrlMenuItem:
            return urlStringInComment(chat) != nil ? true : false
        case addHandleNameMenuItem:
            if live == nil {
                return false
            }
            return (chat.isUserComment || chat.isBSPComment)
        case removeHandleNameMenuItem:
            guard let live = live else {
                return false
            }
            let hasHandleName = (HandleNameManager.sharedManager.handleNameForLive(live, chat: chat) != nil)
            return hasHandleName
        case addToMuteUserMenuItem, reportAsNgUserMenuItem:
            return (chat.isUserComment || chat.isBSPComment)
        case openUserPageMenuItem:
            return (chat.isRawUserId && (chat.isUserComment || chat.isBSPComment)) ? true : false
        default:
            break
        }
        
        return false
    }

    // MARK: - NSMenuDelegate Functions
    func menuWillOpen(_ menu: NSMenu) {
        resetMenu()
        
        let clickedRow = tableView.clickedRow
        if clickedRow == -1 {
            return
        }
        
        let message = MessageContainer.sharedContainer[clickedRow]
        
        if message.messageType != .chat {
            return
        }
        
        configureMenu(message.chat!)
    }
    
    // MARK: Utility
    private func resetMenu() {
    }

    private func configureMenu(_ chat: Chat) {
    }

    // MARK: - Context Menu Handlers
    @IBAction func copyComment(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let toBeCopied = chat.comment!
        _ = copyStringToPasteBoard(toBeCopied)
    }
    
    @IBAction func openUrl(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let urlString = urlStringInComment(chat)!
        NSWorkspace.shared().open(URL(string: urlString)!)
    }
    
    @IBAction func tweetComment(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let live = NicoUtility.sharedInstance.live!
        
        let comment = chat.comment ?? ""
        let liveName = live.title ?? ""
        let communityName = live.community.title ?? ""
        let liveUrl = live.liveUrlString ?? ""
        let communityId = live.community.community ?? ""
        
        let status = "「\(comment)」/ \(liveName) (\(communityName)) \(liveUrl) #\(communityId)"
        
        let service = NSSharingService(named: NSSharingServiceNamePostOnTwitter)
        service?.delegate = self
        
        service?.perform(withItems: [status])
    }
    
    @IBAction func addHandleName(_ sender: AnyObject) {
        guard let live = live, let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat else {
            return
        }
        MainViewController.sharedInstance.showHandleNameAddViewControllerWithLive(live, chat: chat)
    }
    
    @IBAction func removeHandleName(_ sender: AnyObject) {
        guard let live = live, let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat else {
            return
        }
        HandleNameManager.sharedManager.removeHandleNameWithLive(live, chat: chat)
        MainViewController.sharedInstance.refreshHandleName()
    }
    
    @IBAction func addToMuteUser(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        
        let defaults = UserDefaults.standard
        var muteUserIds = defaults.object(forKey: Parameters.MuteUserIds) as? [[String: String]] ?? [[String: String]]()
        
        for muteUserId in muteUserIds {
            if chat.userId == muteUserId[MuteUserIdKey.UserId] {
                logger.debug("mute userid [\(chat.userId)] already registered, so skip")
                return
            }
        }
        
        muteUserIds.append([MuteUserIdKey.UserId: chat.userId!])
        defaults.set(muteUserIds, forKey: Parameters.MuteUserIds)
        defaults.synchronize()
    }
    
    @IBAction func reportAsNgUser(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        NicoUtility.sharedInstance.reportAsNgUser(chat) { userId in
            if userId == nil {
                MainViewController.sharedInstance.logSystemMessageToTableView("Failed to report NG user.")
                return
            }
            
            MainViewController.sharedInstance.logSystemMessageToTableView("Completed to report NG user.")
        }
    }
    
    @IBAction func openUserPage(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let userPageUrlString = NicoUtility.sharedInstance.urlStringForUserId(chat.userId!)
        
        NSWorkspace.shared().open(URL(string: userPageUrlString)!)
    }
    
    // MARK: - Internal Functions
    func urlStringInComment(_ chat: Chat) -> String? {
        if chat.comment == nil {
            return nil
        }
        
        return chat.comment!.extractRegexpPattern("(https?://[\\w/:%#\\$&\\?\\(\\)~\\.=\\+\\-]+)")
    }
    
    func copyStringToPasteBoard(_ string: String) -> Bool {
        let pasteBoard = NSPasteboard.general()
        pasteBoard.declareTypes([NSStringPboardType], owner: nil)
        let result = pasteBoard.setString(string, forType: NSStringPboardType)
        logger.debug("copied \(string) w/ result \(result)")
        
        return result
    }
}
