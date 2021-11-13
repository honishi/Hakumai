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
    @IBOutlet private weak var mainViewController: MainViewController!
    @IBOutlet private weak var copyCommentMenuItem: NSMenuItem!
    @IBOutlet private weak var copyUrlMenuItem: NSMenuItem!
    @IBOutlet private weak var openUrlMenuItem: NSMenuItem!
    @IBOutlet private weak var setHandleNameMenuItem: NSMenuItem!
    @IBOutlet private weak var removeHandleNameMenuItem: NSMenuItem!
    @IBOutlet private weak var addToMuteUserMenuItem: NSMenuItem!
    @IBOutlet private weak var openUserPageMenuItem: NSMenuItem!

    // MARK: Computed Properties
    private var clickedMessage: Message? { mainViewController.clickedMessage }
    private var currentLive: Live? { mainViewController.live }

    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        configureView()
    }
}

extension MenuDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let message = clickedMessage,
              case let .chat(chat) = message.content else { return false }
        switch menuItem {
        case copyCommentMenuItem:
            return true
        case copyUrlMenuItem, openUrlMenuItem:
            return chat.comment.extractUrlString() != nil ? true : false
        case setHandleNameMenuItem:
            guard currentLive != nil else { return false }
            return chat.isUser
        case removeHandleNameMenuItem:
            guard let live = currentLive else { return false }
            let hasHandleName = HandleNameManager.shared.handleName(for: chat.userId, in: live.communityId) != nil
            return hasHandleName
        case addToMuteUserMenuItem:
            return chat.isUser
        case openUserPageMenuItem:
            return chat.isRawUserId && chat.isUser
        default:
            break
        }
        return false
    }
}

extension MenuDelegate {
    // MARK: - Context Menu Handlers
    @IBAction func copyComment(_ sender: AnyObject) {
        guard case let .chat(chat) = clickedMessage?.content else { return }
        chat.comment.copyToPasteBoard()
    }

    @IBAction func copyUrl(_ sender: Any) {
        guard case let .chat(chat) = clickedMessage?.content,
              let urlString = chat.comment.extractUrlString() else { return }
        urlString.copyToPasteBoard()
    }

    @IBAction func openUrl(_ sender: AnyObject) {
        guard case let .chat(chat) = clickedMessage?.content,
              let urlString = chat.comment.extractUrlString(),
              let urlObject = URL(string: urlString) else { return }
        NSWorkspace.shared.open(urlObject)
    }

    @IBAction func addHandleName(_ sender: AnyObject) {
        guard let live = currentLive,
              case let .chat(chat) = clickedMessage?.content else { return }
        mainViewController.showHandleNameAddViewController(live: live, chat: chat)
    }

    @IBAction func removeHandleName(_ sender: AnyObject) {
        guard let live = currentLive,
              case let .chat(chat) = clickedMessage?.content else { return }
        HandleNameManager.shared.removeHandleName(for: chat.userId, in: live.communityId)
        mainViewController.refreshHandleName()
    }

    @IBAction func addToMuteUser(_ sender: AnyObject) {
        guard case let .chat(chat) = clickedMessage?.content else { return }
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
        guard case let .chat(chat) = clickedMessage?.content,
              let url = mainViewController.userPageUrl(for: chat.userId) else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension MenuDelegate {
    func configureView() {
        copyCommentMenuItem.title = L10n.copyComment
        copyUrlMenuItem.title = L10n.copyUrlInComment
        openUrlMenuItem.title = L10n.openUrlInComment
        setHandleNameMenuItem.title = L10n.setHandleName
        removeHandleNameMenuItem.title = L10n.removeHandleName
        addToMuteUserMenuItem.title = L10n.addToMuteUser
        openUserPageMenuItem.title = L10n.openUserPage
    }
}
