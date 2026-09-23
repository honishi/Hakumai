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
    @IBOutlet private weak var setUserColorMenuItem: NSMenuItem!
    @IBOutlet private weak var removeUserColorMenuItem: NSMenuItem!
    @IBOutlet private weak var addToMuteUserMenuItem: NSMenuItem!
    @IBOutlet private weak var openUserPageMenuItem: NSMenuItem!

    // MARK: Computed Properties
    private var clickedMessage: Message? { mainViewController.clickedMessage }
    private var currentLive: Live? { mainViewController.live }

    private let userColorPanel = UserColorPanel()

    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        configureView()
    }
}

extension MenuDelegate: NSMenuItemValidation {
    // swiftlint:disable cyclomatic_complexity
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem == copyCommentMenuItem {
            return !mainViewController.contextMenuCopyRows.isEmpty
        }
        guard let message = clickedMessage,
              case let .chat(chat) = message.content else { return false }
        switch menuItem {
        case copyUrlMenuItem, openUrlMenuItem:
            return chat.comment.extractUrlString() != nil ? true : false
        case setHandleNameMenuItem, setUserColorMenuItem:
            guard currentLive != nil else { return false }
            return chat.isUser
        case removeHandleNameMenuItem:
            guard let live = currentLive else { return false }
            let hasHandleName = HandleNameManager.shared.handleName(
                for: chat.userId,
                in: live.programProvider.programProviderId
            ) != nil
            return hasHandleName
        case removeUserColorMenuItem:
            guard let live = currentLive else { return false }
            let hasColor = HandleNameManager.shared.color(
                for: chat.userId,
                in: live.programProvider.programProviderId
            ) != nil
            return hasColor
        case addToMuteUserMenuItem:
            return chat.isUser
        case openUserPageMenuItem:
            return chat.isRawUserId && chat.isUser
        default:
            break
        }
        return false
    }
    // swiftlint:enable cyclomatic_complexity
}

extension MenuDelegate {
    // MARK: - Context Menu Handlers
    @IBAction func copyComment(_ sender: AnyObject) {
        mainViewController.copyMessages(at: mainViewController.contextMenuCopyRows)
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
        HandleNameManager.shared.removeHandleName(
            for: chat.userId,
            in: live.programProvider.programProviderId
        )
        mainViewController.reloadTableView()
    }

    @IBAction func setUserColor(_ sender: Any) {
        guard let live = currentLive,
              case let .chat(chat) = clickedMessage?.content else { return }
        userColorPanel.targetUser = UserColorPanel.User(
            userId: chat.userId,
            providerId: live.programProvider.programProviderId
        )
        userColorPanel.makeKeyAndOrderFront(nil)
    }

    @objc private func userColorSelected(_ sender: UserColorPanel) {
        guard let user = sender.targetUser else { return }
        HandleNameManager.shared.setColor(sender.color, for: user.userId, in: user.providerId)
        mainViewController.reloadTableView()
    }

    @IBAction func removeUserColor(_ sender: Any) {
        guard let live = currentLive,
              case let .chat(chat) = clickedMessage?.content else { return }
        HandleNameManager.shared.removeColor(
            for: chat.userId,
            in: live.programProvider.programProviderId
        )
        mainViewController.reloadTableView()
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

enum MessageCopy {
    // 選択範囲上の右クリックは複数行コピー、範囲外の右クリックは従来どおりその行だけを対象にする。
    static func contextMenuRows(clickedRow: Int, selectedRows: IndexSet, messageCount: Int) -> IndexSet {
        let validRows = IndexSet(integersIn: 0..<messageCount)
        guard validRows.contains(clickedRow) else { return [] }
        if selectedRows.contains(clickedRow) {
            return selectedRows.intersection(validRows)
        }
        return IndexSet(integer: clickedRow)
    }

    static func text(messages: [Message], rows: IndexSet) -> String? {
        // 診断ログをコメントと一緒に共有できるよう、画面の行順と debug の xN 表示をそのまま使う。
        // rows は表示配列の添字なので、呼び出し元はフィルター済み配列のスナップショットを渡す。
        let validRows = rows.intersection(IndexSet(integersIn: messages.indices))
        guard !validRows.isEmpty else { return nil }
        return validRows.map { row in
            switch messages[row].content {
            case .chat(let chat): return chat.comment
            case .debug(let debug): return debug.displayMessage
            case .system(let system): return system.message
            }
        }.joined(separator: "\n")
    }
}

private extension MenuDelegate {
    func configureView() {
        copyCommentMenuItem.title = L10n.copyComment
        copyUrlMenuItem.title = L10n.copyUrlInComment
        openUrlMenuItem.title = L10n.openUrlInComment
        setHandleNameMenuItem.title = L10n.setHandleName
        removeHandleNameMenuItem.title = L10n.removeHandleName
        setUserColorMenuItem.title = L10n.setUserColor
        removeUserColorMenuItem.title = L10n.removeUserColor
        addToMuteUserMenuItem.title = L10n.addToMuteUser
        openUserPageMenuItem.title = L10n.openUserPage

        userColorPanel.setTarget(self)
        userColorPanel.setAction(#selector(userColorSelected(_:)))
        userColorPanel.isContinuous = true
        userColorPanel.showsAlpha = true
    }
}

private final class UserColorPanel: NSColorPanel {
    struct User {
        let userId: String
        let providerId: String
    }
    var targetUser: User?
}
