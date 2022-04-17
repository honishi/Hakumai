//
//  UserViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import Kingfisher

private let defaultLabelValue = "-----"

final class UserViewController: NSViewController {
    // MARK: - Properties
    // MARK: Outlets
    @IBOutlet private weak var userIconImageView: NSImageView!
    @IBOutlet private weak var userIdTitleLabel: NSTextField!
    @IBOutlet private weak var userIdButton: NSButton!
    @IBOutlet private weak var userIdCopyButton: NSButton!
    @IBOutlet private weak var userNameTitleLabel: NSTextField!
    @IBOutlet private weak var userNameValueLabel: NSTextField!
    @IBOutlet private weak var handleNameTitleLabel: NSTextField!
    @IBOutlet private weak var handleNameValueLabel: NSTextField!
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var scrollView: ButtonScrollView!

    // MARK: Basics
    private var nicoManager: NicoManagerType!
    private var messageContainer: MessageContainer!
    private var userId: String = ""
    private var handleName: String?
    private var messages = [Message]()
    private var rowHeightCacher = [Int: CGFloat]()

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - NSViewController Functions
extension UserViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        registerNibs()
    }

    private func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameTimeTableCellView, kTimeColumnIdentifier),
            (kNibNameCommentTableCellView, kCommentColumnIdentifier)]
        for (nibName, identifier) in nibs {
            guard let nib = NSNib(nibNamed: nibName, bundle: Bundle.main) else { continue }
            let itemIdentifier = NSUserInterfaceItemIdentifier(rawValue: identifier)
            tableView.register(nib, forIdentifier: itemIdentifier)
        }
    }
}

// MARK: - NSTableViewDataSource Functions
extension UserViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return messages.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = messages[row]

        if let cached = rowHeightCacher[message.messageNo] {
            return cached
        }

        var rowHeight: CGFloat = 0

        let itemIdentifier = NSUserInterfaceItemIdentifier(rawValue: kCommentColumnIdentifier)
        guard let commentTableColumn = tableView.tableColumn(withIdentifier: itemIdentifier) else {
            return rowHeight
        }
        let commentColumnWidth = commentTableColumn.width
        rowHeight = commentColumnHeight(forMessage: message, width: commentColumnWidth)

        rowHeightCacher[message.messageNo] = rowHeight

        return rowHeight
    }

    private func commentColumnHeight(forMessage message: Message, width: CGFloat) -> CGFloat {
        let (content, attributes) = contentAndAttributes(forMessage: message)
        return CommentTableCellView.calculateHeight(
            text: content,
            attributes: attributes,
            hasGiftImage: message.giftImageUrl != nil,
            columnWidth: width
        )
    }

    func tableViewColumnDidResize(_ aNotification: Notification) {
        guard let column = (aNotification as NSNotification).userInfo?["NSTableColumn"] as? NSTableColumn else { return }
        if column.identifier.rawValue == kCommentColumnIdentifier {
            rowHeightCacher.removeAll(keepingCapacity: false)
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var view: NSTableCellView?
        if let identifier = tableColumn?.identifier {
            view = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            view?.textField?.stringValue = ""
        }
        let message = messages[row]
        switch message.content {
        case .system, .debug:
            break
        case .chat:
            guard let _view = view, let tableColumn = tableColumn else { break }
            configure(view: _view, forChat: message, withTableColumn: tableColumn)
        }
        return view
    }
}

extension UserViewController {
    func set(nicoManager: NicoManagerType, messageContainer: MessageContainer, userId: String, handleName: String?) {
        reset()

        self.nicoManager = nicoManager
        self.messageContainer = messageContainer
        self.userId = userId
        self.handleName = handleName

        // User Icon
        if let userIconUrl = nicoManager.userIconUrl(for: userId) {
            userIconImageView.kf.setImage(
                with: userIconUrl,
                placeholder: Asset.defaultUserImage.image
            )
        }
        // User ID
        userIdButton.title = userId
        // UserName
        if let userName = nicoManager.cachedUserName(for: userId) {
            userNameValueLabel.stringValue = userName
        } else {
            userNameValueLabel.stringValue = defaultLabelValue
            resolveUserName(for: userId)
        }
        // Handle Name
        handleNameValueLabel.stringValue = handleName ?? "(Not Set)"
        // Messages
        reloadMessages()
    }

    func reloadMessages() {
        messages = messageContainer.messages(fromUserId: userId)
        let shouldScroll = scrollView.isReachedToBottom
        tableView.reloadData()
        if shouldScroll {
            scrollView.scrollToBottom()
        }
        scrollView.flashScrollers()
        // Use main queue here. This ensures the `updateBottomButtonVisibility()` call is
        // executed after the completion of `tableView.reloadData()` for sure.
        // (`updateBottomButtonVisibility()` needs to be called after `tableView.reloadData()` call.)
        DispatchQueue.main.async { self.scrollView.updateButtonEnables() }
    }

    @IBAction func userIdButtonPressed(_ sender: Any) {
        guard userId.isRawUserId,
              let url = nicoManager.userPageUrl(for: userId) else { return }
        NSWorkspace.shared.open(url)
    }

    @IBAction func userIdCopyButtonPressed(_ sender: Any) {
        userId.copyToPasteBoard()
    }
}

private extension UserViewController {
    func configureView() {
        userIdTitleLabel.stringValue = "\(L10n.userId):"
        userIdCopyButton.title = L10n.copyUserId
        userNameTitleLabel.stringValue = "\(L10n.userName):"
        handleNameTitleLabel.stringValue = "\(L10n.handleName):"
        scrollView.enableScrollButtons()
    }

    func configure(view: NSTableCellView, forChat message: Message, withTableColumn tableColumn: NSTableColumn) {
        var attributed: NSAttributedString?

        switch tableColumn.identifier.rawValue {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.configure(message: message)
        case kTimeColumnIdentifier:
            (view as? TimeTableCellView)?.configure(live: nicoManager.live, message: message)
        case kCommentColumnIdentifier:
            let commentView = view as? CommentTableCellView
            let (content, attributes) = contentAndAttributes(forMessage: message)
            attributed = NSAttributedString(string: content, attributes: attributes)
            commentView?.configure(
                attributedString: attributed,
                giftImageUrl: message.giftImageUrl
            )
        default:
            break
        }
    }

    func reset() {
        messages.removeAll(keepingCapacity: false)
        rowHeightCacher.removeAll(keepingCapacity: false)
    }

    func resolveUserName(for userId: String?) {
        guard let userId = userId else { return }
        nicoManager.resolveUsername(for: userId) { [weak self] in
            guard let resolved = $0 else { return }
            DispatchQueue.main.async { self?.userNameValueLabel.stringValue = resolved }
        }
    }

    // MARK: Utility
    func contentAndAttributes(forMessage message: Message) -> (String, [NSAttributedString.Key: Any]) {
        let content: String
        let attributes: [NSAttributedString.Key: Any]

        switch message.content {
        case .system(let system):
            content = system.message
            attributes = UIHelper.commentAttributes()
        case .chat(let chat):
            content = chat.comment
            attributes = UIHelper.commentAttributes(isBold: chat.isFirst)
        case .debug(let debug):
            content = debug.message
            attributes = UIHelper.commentAttributes()
        }

        return (content, attributes)
    }
}
