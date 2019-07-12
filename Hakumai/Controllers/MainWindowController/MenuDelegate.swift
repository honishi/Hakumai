//
//  MenuDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/4/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class MenuDelegate: NSObject, NSMenuDelegate, NSSharingServiceDelegate {
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
    // swiftlint:disable cyclomatic_complexity
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let clickedRow = tableView.clickedRow
        if clickedRow == -1 {
            return false
        }

        let message = MessageContainer.sharedContainer[clickedRow]
        guard message.messageType == .chat, let chat = message.chat else { return false }

        switch menuItem {
        case copyCommentMenuItem, tweetCommentMenuItem:
            return true
        case openUrlMenuItem:
            return chat.comment?.extractUrlString() != nil ? true : false
        case addHandleNameMenuItem:
            guard live != nil else { return false }
            return (chat.isUserComment || chat.isBSPComment)
        case removeHandleNameMenuItem:
            guard let live = live else { return false }
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
    // swiftlint:enable cyclomatic_complexity

    // MARK: - NSMenuDelegate Functions
    func menuWillOpen(_ menu: NSMenu) {
        resetMenu()
        guard tableView.clickedRow != -1 else { return }
        let message = MessageContainer.sharedContainer[tableView.clickedRow]
        guard message.messageType == .chat, let chat = message.chat else { return }
        configureMenu(chat)
    }

    // MARK: Utility
    private func resetMenu() {}
    private func configureMenu(_ chat: Chat) {}

    // MARK: - Context Menu Handlers
    @IBAction func copyComment(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let toBeCopied = chat.comment!
        _ = copyStringToPasteBoard(toBeCopied)
    }

    @IBAction func openUrl(_ sender: AnyObject) {
        let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat!
        let url = chat.comment!.extractUrlString()!
        NSWorkspace.shared.open(URL(string: url)!)
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

        let service = NSSharingService(named: NSSharingService.Name.postOnTwitter)
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
        guard let chat = MessageContainer.sharedContainer[tableView.clickedRow].chat,
            let userId = chat.userId else { return }
        let defaults = UserDefaults.standard
        var muteUserIds = defaults.object(forKey: Parameters.muteUserIds) as? [[String: String]] ?? [[String: String]]()
        for muteUserId in muteUserIds where chat.userId == muteUserId[MuteUserIdKey.userId] {
            log.debug("mute userid [\(chat.userId ?? "")] already registered, so skip")
            return
        }
        muteUserIds.append([MuteUserIdKey.userId: userId])
        defaults.set(muteUserIds, forKey: Parameters.muteUserIds)
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
        NSWorkspace.shared.open(URL(string: userPageUrlString)!)
    }

    // MARK: - Internal Functions
    func copyStringToPasteBoard(_ string: String) -> Bool {
        return true
        // TODO: update for swift 4
        /*
         let pasteBoard = NSPasteboard.general
         pasteBoard.declareTypes(convertToNSPasteboardPasteboardTypeArray([NSStringPboardType.rawValue]), owner: nil)
         let result = pasteBoard.setString(string, forType: convertToNSPasteboardPasteboardType(NSStringPboardType.rawValue))
         log.debug("copied \(string) w/ result \(result)")

         return result
         */
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToNSPasteboardPasteboardTypeArray(_ input: [String]) -> [NSPasteboard.PasteboardType] {
    return input.map { key in NSPasteboard.PasteboardType(key) }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToNSPasteboardPasteboardType(_ input: String) -> NSPasteboard.PasteboardType {
    return NSPasteboard.PasteboardType(rawValue: input)
}
