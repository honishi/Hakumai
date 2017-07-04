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
        return MainViewController.shared.tableView
    }
    
    var live: Live? {
        return MainViewController.shared.live
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
            return urlString(inComment: chat) != nil ? true : false
        case addHandleNameMenuItem:
            if live == nil {
                return false
            }
            return (chat.isUserComment || chat.isBSPComment)
        case removeHandleNameMenuItem:
            guard let live = live else {
                return false
            }
            let hasHandleName = (HandleNameManager.sharedManager.handleName(forLive: live, chat: chat) != nil)
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
        let url = urlString(inComment: chat)!
        NSWorkspace.shared().open(URL(string: url)!)
    }
    
    @IBAction func tweetComment(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let live = NicoUtility.shared.live!
        
        let comment = chat.comment ?? ""
        let liveName = live.title ?? ""
        let communityName = live.community.title ?? ""
        let liveUrl = live.liveUrlString
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
        MainViewController.shared.showHandleNameAddViewController(live: live, chat: chat)
    }
    
    @IBAction func removeHandleName(_ sender: AnyObject) {
        guard let live = live, let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat else {
            return
        }
        HandleNameManager.sharedManager.removeHandleName(live: live, chat: chat)
        MainViewController.shared.refreshHandleName()
    }
    
    @IBAction func addToMuteUser(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        
        let defaults = UserDefaults.standard
        var muteUserIds = defaults.object(forKey: Parameters.MuteUserIds) as? [[String: String]] ?? [[String: String]]()
        
        for muteUserId in muteUserIds {
            if chat.userId == muteUserId[MuteUserIdKey.UserId] {
                logger.debug("mute userid [\(chat.userId ?? "")] already registered, so skip")
                return
            }
        }
        
        muteUserIds.append([MuteUserIdKey.UserId: chat.userId!])
        defaults.set(muteUserIds, forKey: Parameters.MuteUserIds)
        defaults.synchronize()
    }
    
    @IBAction func reportAsNgUser(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        NicoUtility.shared.reportAsNgUser(chat: chat) { userId in
            if userId == nil {
                MainViewController.shared.logSystemMessageToTableView("Failed to report NG user.")
                return
            }
            
            MainViewController.shared.logSystemMessageToTableView("Completed to report NG user.")
        }
    }
    
    @IBAction func openUserPage(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let userPageUrlString = NicoUtility.shared.urlString(forUserId: chat.userId!)
        
        NSWorkspace.shared().open(URL(string: userPageUrlString)!)
    }
    
    // MARK: - Internal Functions
    func urlString(inComment chat: Chat) -> String? {
        if chat.comment == nil {
            return nil
        }
        
        return chat.comment!.extractRegexp(pattern: "(https?://[\\w/:%#\\$&\\?\\(\\)~\\.=\\+\\-]+)")
    }
    
    func copyStringToPasteBoard(_ string: String) -> Bool {
        let pasteBoard = NSPasteboard.general()
        pasteBoard.declareTypes([NSStringPboardType], owner: nil)
        let result = pasteBoard.setString(string, forType: NSStringPboardType)
        logger.debug("copied \(string) w/ result \(result)")
        
        return result
    }
}
