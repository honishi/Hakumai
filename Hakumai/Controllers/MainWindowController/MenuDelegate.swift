//
//  MenuDelegate.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/4/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class MenuDelegate: NSObject {
    // MARK: Menu Outlets
    @IBOutlet private weak var copyCommentMenuItem: NSMenuItem!
    @IBOutlet private weak var openUrlMenuItem: NSMenuItem!
    @IBOutlet private weak var setHandleNameMenuItem: NSMenuItem!
    @IBOutlet private weak var removeHandleNameMenuItem: NSMenuItem!
    @IBOutlet private weak var addToMuteUserMenuItem: NSMenuItem!
    @IBOutlet private weak var openUserPageMenuItem: NSMenuItem!
    @IBOutlet private weak var mainViewController: MainViewController!

    // MARK: Computed Properties
    // TODO: refactor to `clickedChat`
    private var messageContainer: MessageContainer { mainViewController.messageContainer }
    // TODO: integrate to `clickedChat`
    private var clickedRow: Int { mainViewController.clickedRow }
    private var live: Live? { mainViewController.live }

    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        configureView()
    }
}

extension MenuDelegate: NSMenuItemValidation {
    // swiftlint:disable cyclomatic_complexity
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard clickedRow != -1 else { return false }

        let message = messageContainer[clickedRow]
        guard message.messageType == .chat, let chat = message.chat else { return false }

        switch menuItem {
        case copyCommentMenuItem:
            return true
        case openUrlMenuItem:
            return chat.comment.extractUrlString() != nil ? true : false
        case setHandleNameMenuItem:
            guard live != nil else { return false }
            return chat.isUserComment
        case removeHandleNameMenuItem:
            guard let live = live else { return false }
            let hasHandleName = (HandleNameManager.shared.handleName(forLive: live, chat: chat) != nil)
            return hasHandleName
        case addToMuteUserMenuItem:
            return chat.isUserComment
        case openUserPageMenuItem:
            return (chat.isRawUserId && chat.isUserComment) ? true : false
        default:
            break
        }

        return false
    }
    // swiftlint:enable cyclomatic_complexity
}

extension MenuDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        resetMenu()
        guard clickedRow != -1 else { return }
        let message = messageContainer[clickedRow]
        guard message.messageType == .chat, let chat = message.chat else { return }
        configureMenu(chat)
    }
}

extension MenuDelegate: NSSharingServiceDelegate {}

extension MenuDelegate {
    // MARK: - Context Menu Handlers
    @IBAction func copyComment(_ sender: AnyObject) {
        guard let chat = messageContainer[clickedRow].chat else { return }
        _ = copyStringToPasteBoard(chat.comment)
    }

    @IBAction func openUrl(_ sender: AnyObject) {
        guard let chat = messageContainer[clickedRow].chat,
              let urlString = chat.comment.extractUrlString(),
              let urlObject = URL(string: urlString) else { return }
        NSWorkspace.shared.open(urlObject)
    }

    @IBAction func addHandleName(_ sender: AnyObject) {
        guard let live = live, let chat = messageContainer[clickedRow].chat else {
            return
        }
        mainViewController.showHandleNameAddViewController(live: live, chat: chat)
    }

    @IBAction func removeHandleName(_ sender: AnyObject) {
        guard let live = live, let chat = messageContainer[clickedRow].chat else {
            return
        }
        HandleNameManager.shared.removeHandleName(live: live, chat: chat)
        mainViewController.refreshHandleName()
    }

    @IBAction func addToMuteUser(_ sender: AnyObject) {
        guard let chat = messageContainer[clickedRow].chat else { return }
        let defaults = UserDefaults.standard
        var muteUserIds = defaults.object(forKey: Parameters.muteUserIds) as? [[String: String]] ?? [[String: String]]()
        for muteUserId in muteUserIds where chat.userId == muteUserId[MuteUserIdKey.userId] {
            log.debug("mute userid [\(chat.userId)] already registered, so skip")
            return
        }
        muteUserIds.append([MuteUserIdKey.userId: chat.userId])
        defaults.set(muteUserIds, forKey: Parameters.muteUserIds)
        defaults.synchronize()
    }

    @IBAction func openUserPage(_ sender: AnyObject) {
        guard let userId = messageContainer[clickedRow].chat?.userId,
              let url = mainViewController.nicoUtility.userPageUrl(for: userId) else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension MenuDelegate {
    func configureView() {
        copyCommentMenuItem.title = L10n.copyComment
        openUrlMenuItem.title = L10n.openUrlInComment
        setHandleNameMenuItem.title = L10n.setHandleName
        removeHandleNameMenuItem.title = L10n.removeHandleName
        addToMuteUserMenuItem.title = L10n.addToMuteUser
        openUserPageMenuItem.title = L10n.openUserPage
    }

    func resetMenu() {}
    func configureMenu(_ chat: Chat) {}

    func copyStringToPasteBoard(_ string: String) -> Bool {
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        let result = pasteBoard.setString(string, forType: .string)
        log.debug("copied \(string) w/ result \(result)")
        return result
    }
}
