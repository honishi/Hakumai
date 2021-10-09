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
    @IBOutlet private weak var scrollView: BottomButtonScrollView!

    // MARK: Basics
    private var nicoUtility: NicoUtility!
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
            (kNibNameScoreTableCellView, kScoreColumnIdentifier),
            (kNibNameCommentTableCellView, kCommentColumnIdentifier)]
        for (nibName, identifier) in nibs {
            guard let nib = NSNib(nibNamed: nibName, bundle: Bundle.main) else { continue }
            tableView.register(nib, forIdentifier: convertToNSUserInterfaceItemIdentifier(identifier))
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

        guard let commentTableColumn = tableView.tableColumn(withIdentifier: convertToNSUserInterfaceItemIdentifier(kCommentColumnIdentifier)) else { return rowHeight }
        let commentColumnWidth = commentTableColumn.width
        rowHeight = commentColumnHeight(forMessage: message, width: commentColumnWidth)

        rowHeightCacher[message.messageNo] = rowHeight

        return rowHeight
    }

    private func commentColumnHeight(forMessage message: Message, width: CGFloat) -> CGFloat {
        let leadingSpace: CGFloat = 2
        let trailingSpace: CGFloat = 2
        let widthPadding = leadingSpace + trailingSpace

        let (content, attributes) = contentAndAttributes(forMessage: message)

        let commentRect = content.boundingRect(with: CGSize(width: width - widthPadding, height: 0),
                                               options: NSString.DrawingOptions.usesLineFragmentOrigin, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")

        return commentRect.size.height
    }

    func tableViewColumnDidResize(_ aNotification: Notification) {
        guard let column = (aNotification as NSNotification).userInfo?["NSTableColumn"] as? NSTableColumn else { return }
        if convertFromNSUserInterfaceItemIdentifier(column.identifier) == kCommentColumnIdentifier {
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
        if message.messageType == .chat, let _view = view, let tableColumn = tableColumn {
            configure(view: _view, forChat: message, withTableColumn: tableColumn)
        }
        return view
    }
}

extension UserViewController {
    func set(nicoUtility: NicoUtility, messageContainer: MessageContainer, userId: String, handleName: String?) {
        reset()

        self.nicoUtility = nicoUtility
        self.messageContainer = messageContainer
        self.userId = userId
        self.handleName = handleName

        // User Icon
        if let userIconUrl = nicoUtility.userIconUrl(for: userId) {
            userIconImageView.kf.setImage(
                with: userIconUrl,
                placeholder: Asset.defaultUserImage.image
            )
        }
        // User ID
        userIdButton.title = userId
        // UserName
        if let userName = nicoUtility.cachedUserName(forUserId: userId) {
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
        DispatchQueue.main.async {
            self.scrollView.updateBottomButtonVisibility()
        }
    }

    @IBAction func userIdButtonPressed(_ sender: Any) {
        guard Chat.isRawUserId(userId),
              let url = nicoUtility.userPageUrl(for: userId) else { return }
        NSWorkspace.shared.open(url)
    }

    @IBAction func userIdCopyButtonPressed(_ sender: Any) {
        userId.copyToPasteBoard()
    }
}

private extension UserViewController {
    func configureView() {
        userIconImageView.addBorder()
        userIdTitleLabel.stringValue = "\(L10n.userId):"
        userIdCopyButton.title = L10n.copyUserId
        userNameTitleLabel.stringValue = "\(L10n.userName):"
        handleNameTitleLabel.stringValue = "\(L10n.handleName):"
        scrollView.enableBottomScrollButton()
    }

    func configure(view: NSTableCellView, forChat message: Message, withTableColumn tableColumn: NSTableColumn) {
        guard let chat = message.chat else { return }

        var attributed: NSAttributedString?

        switch convertFromNSUserInterfaceItemIdentifier(tableColumn.identifier) {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = chat.roomPosition
            roomPositionView?.commentNo = chat.no
        case kScoreColumnIdentifier:
            // TODO: live
            (view as? ScoreTableCellView)?.configure(live: nil, chat: chat)
        case kCommentColumnIdentifier:
            let commentView = view as? CommentTableCellView
            let (content, attributes) = contentAndAttributes(forMessage: message)
            attributed = NSAttributedString(string: content, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
            commentView?.attributedString = attributed
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
        nicoUtility.resolveUsername(forUserId: userId) { [weak self] in
            guard let resolved = $0 else { return }
            DispatchQueue.main.async { self?.userNameValueLabel.stringValue = resolved }
        }
    }

    // MARK: Utility
    func contentAndAttributes(forMessage message: Message) -> (String, [String: Any]) {
        var content: String!
        var attributes = [String: Any]()

        if message.messageType == .system, let _message = message.message {
            content = _message
            attributes = UIHelper.normalCommentAttributes()
        } else if message.messageType == .chat, let _message = message.chat?.comment {
            content = _message
            attributes = (message.firstChat == true ? UIHelper.boldCommentAttributes() : UIHelper.normalCommentAttributes())
        }

        return (content, attributes)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToNSUserInterfaceItemIdentifier(_ input: String) -> NSUserInterfaceItemIdentifier {
    return NSUserInterfaceItemIdentifier(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier) -> String {
    return input.rawValue
}
