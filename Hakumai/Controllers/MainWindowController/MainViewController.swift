//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kStoryboardNameMainWindowController = "MainWindowController"
private let kStoryboardIdHandleNameAddViewController = "HandleNameAddViewController"

private let kConnectButtonImageNameStart = "StartLive"
private let kConnectButtonImageNameStop = "StopLive"
private let kCommunityImageDefaultName = "NoImage"
private let kUserWindowDefautlTopLeftPoint = NSPoint(x: 100, y: 100)
private let kCalculateActiveInterval: TimeInterval = 5
private let kMaximumFontSizeForNonMainColumn: CGFloat = 16
private let kDefaultMinimumRowHeight: CGFloat = 17

private let safariCookieAlertTitle = "No Safari Cookie found"
private let safariCookieAlertDescription = "To retrieve the cookie from Safari, please open the Security & Privacy section of the System Preference and give the \"Full Disk Access\" right to Hakumai app."
private let safariCookieAlertImageName = "safariCookieAlertImage"

// swiftlint:disable file_length
final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate, NicoUtilityDelegate, UserWindowControllerDelegate {
    // MARK: - Properties
    static var shared: MainViewController!

    // MARK: Main Outlets
    @IBOutlet weak var liveTextField: NSTextField!

    @IBOutlet weak var communityImageView: NSImageView!
    @IBOutlet weak var liveTitleLabel: NSTextField!
    @IBOutlet weak var communityTitleLabel: NSTextField!
    @IBOutlet weak var communityIdLabel: NSTextField!

    @IBOutlet weak var visitorsLabel: NSTextField!
    @IBOutlet weak var commentsLabel: NSTextField!
    @IBOutlet weak var remainingSeatsLabel: NSTextField!

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!

    @IBOutlet weak var commentTextField: NSTextField!
    @IBOutlet weak var connectButton: NSButton!
    @IBOutlet weak var commentAnonymouslyButton: NSButton!
    @IBOutlet weak var elapsedLabel: NSTextField!
    @IBOutlet weak var activeLabel: NSTextField!
    @IBOutlet weak var notificationLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    // MARK: Menu Delegate
    // swiftlint:disable weak_delegate
    @IBOutlet var menuDelegate: MenuDelegate!
    // swiftlint:enable weak_delegate

    // MARK: General Properties
    private(set) var live: Live?
    private var connectedToLive = false
    private var openedRoomPosition: RoomPosition?
    private var chats = [Chat]()

    // row-height cache
    private var rowHeightCacher = [Int: CGFloat]()
    private var minimumRowHeight: CGFloat = kDefaultMinimumRowHeight
    private var lastShouldScrollToBottom = true
    private var currentScrollAnimationCount = 0
    private var tableViewFontSize: CGFloat = CGFloat(kDefaultFontSize)

    private var commentHistory = [String]()
    private var commentHistoryIndex: Int = 0

    private var elapsedTimer: Timer?
    private var activeTimer: Timer?

    private var userWindowControllers = [UserWindowController]()
    private var nextUserWindowTopLeftPoint: NSPoint = NSPoint.zero
}

extension MainViewController {
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        MainViewController.shared = self
    }

    // MARK: - NSViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()

        buildViews()
        setupTableView()
        registerNibs()
    }

    override func viewDidAppear() {
        // kickTableViewStressTest()
        // updateStandardUserDefaults()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    // MARK: Configure Views
    private func buildViews() {
        // use async to properly render border line. if not async, the line sometimes disappears
        DispatchQueue.main.async {
            self.communityImageView.layer?.borderWidth = 0.5
            self.communityImageView.layer?.masksToBounds = true
            self.communityImageView.layer?.borderColor = NSColor.black.cgColor
        }
    }

    private func setupTableView() {
        tableView.doubleAction = #selector(MainViewController.openUserWindow(_:))
    }

    private func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameScoreTableCellView, kScoreColumnIdentifier),
            (kNibNameUserIdTableCellView, kUserIdColumnIdentifier),
            (kNibNamePremiumTableCellView, kPremiumColumnIdentifier)]

        for (nibName, identifier) in nibs {
            guard let nib = NSNib(nibNamed: nibName, bundle: Bundle.main) else { continue }
            tableView.register(nib, forIdentifier: convertToNSUserInterfaceItemIdentifier(identifier))
        }
    }

    // MARK: Utility
    func changeEnableCommentSpeech(_ enabled: Bool) {
        // log.debug("\(enabled)")
        updateSpeechManagerState()
    }

    func changeFontSize(_ fontSize: CGFloat) {
        tableViewFontSize = fontSize

        minimumRowHeight = calculateMinimumRowHeight(fontSize: tableViewFontSize)
        tableView.rowHeight = minimumRowHeight
        rowHeightCacher.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }

    func changeEnableMuteUserIds(_ enabled: Bool) {
        MessageContainer.sharedContainer.enableMuteUserIds = enabled
        log.debug("changed enable mute userids: \(enabled)")

        rebuildFilteredMessages()
    }

    func changeMuteUserIds(_ muteUserIds: [[String: String]]) {
        MessageContainer.sharedContainer.muteUserIds = muteUserIds
        log.debug("changed mute userids: \(muteUserIds)")

        rebuildFilteredMessages()
    }

    func changeEnableMuteWords(_ enabled: Bool) {
        MessageContainer.sharedContainer.enableMuteWords = enabled
        log.debug("changed enable mute words: \(enabled)")

        rebuildFilteredMessages()
    }

    func changeMuteWords(_ muteWords: [[String: String]]) {
        MessageContainer.sharedContainer.muteWords = muteWords
        log.debug("changed mute words: \(muteWords)")

        rebuildFilteredMessages()
    }

    private func rebuildFilteredMessages() {
        DispatchQueue.main.async {
            self.progressIndicator.startAnimation(self)
            let shouldScroll = self.shouldTableViewScrollToBottom()

            MessageContainer.sharedContainer.rebuildFilteredMessages {
                self.tableView.reloadData()

                if shouldScroll {
                    self.scrollTableViewToBottom()
                }
                self.scrollView.flashScrollers()

                self.progressIndicator.stopAnimation(self)
            }
        }
    }

    // MARK: - NSTableViewDataSource Functions
    func numberOfRows(in tableView: NSTableView) -> Int {
        return MessageContainer.sharedContainer.count()
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = MessageContainer.sharedContainer[row]

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

        let commentRect = content.boundingRect(
            with: CGSize(width: width - widthPadding, height: 0), options: NSString.DrawingOptions.usesLineFragmentOrigin,
            attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")

        return max(commentRect.size.height, minimumRowHeight)
    }

    private func calculateMinimumRowHeight(fontSize: CGFloat) -> CGFloat {
        let placeholderContent = "." as NSString
        let placeholderAttributes = UIHelper.normalCommentAttributes(fontSize: fontSize)
        let rect = placeholderContent.boundingRect(
            with: CGSize(width: 1, height: 0), options: NSString.DrawingOptions.usesLineFragmentOrigin, attributes: convertToOptionalNSAttributedStringKeyDictionary(placeholderAttributes))
        return rect.size.height
    }

    func tableViewColumnDidResize(_ aNotification: Notification) {
        guard let column = (aNotification as NSNotification).userInfo?["NSTableColumn"] as? NSTableColumn else {
            return
        }
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

        let message = MessageContainer.sharedContainer[row]

        guard let _view = view, let tableColumn = tableColumn else { return nil }

        if message.messageType == .system {
            configure(view: _view, forSystemMessage: message, withTableColumn: tableColumn)
        } else if message.messageType == .chat {
            configure(view: _view, forChat: message, withTableColumn: tableColumn)
        }

        return view
    }

    private func configure(view: NSTableCellView, forSystemMessage message: Message, withTableColumn tableColumn: NSTableColumn) {
        switch convertFromNSUserInterfaceItemIdentifier(tableColumn.identifier) {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = nil
            roomPositionView?.commentNo = nil
            roomPositionView?.fontSize = nil
        case kScoreColumnIdentifier:
            let scoreView = view as? ScoreTableCellView
            scoreView?.chat = nil
            scoreView?.fontSize = nil
        case kCommentColumnIdentifier:
            let (content, attributes) = contentAndAttributes(forMessage: message)
            let attributed = NSAttributedString(string: content, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
            view.textField?.attributedStringValue = attributed
        case kUserIdColumnIdentifier:
            let userIdView = view as? UserIdTableCellView
            userIdView?.info = nil
            userIdView?.fontSize = nil
        case kPremiumColumnIdentifier:
            let premiumView = view as? PremiumTableCellView
            premiumView?.premium = nil
            premiumView?.fontSize = nil
        default:
            break
        }
    }

    private func configure(view: NSTableCellView, forChat message: Message, withTableColumn tableColumn: NSTableColumn) {
        guard let chat = message.chat else { return }

        switch convertFromNSUserInterfaceItemIdentifier(tableColumn.identifier) {
        case kRoomPositionColumnIdentifier:
            guard let roomPosition = chat.roomPosition, let no = chat.no else { return }
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = roomPosition
            roomPositionView?.commentNo = no
            roomPositionView?.fontSize = min(tableViewFontSize, kMaximumFontSizeForNonMainColumn)
        case kScoreColumnIdentifier:
            let scoreView = view as? ScoreTableCellView
            scoreView?.chat = chat
            scoreView?.fontSize = min(tableViewFontSize, kMaximumFontSizeForNonMainColumn)
        case kCommentColumnIdentifier:
            let (content, attributes) = contentAndAttributes(forMessage: message)
            let attributed = NSAttributedString(string: content as String, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
            view.textField?.attributedStringValue = attributed
        case kUserIdColumnIdentifier:
            guard let live = live else { return }
            let userIdView = view as? UserIdTableCellView
            let handleName = HandleNameManager.sharedManager.handleName(forLive: live, chat: chat)
            userIdView?.info = (handleName: handleName, userId: chat.userId, premium: chat.premium, comment: chat.comment)
            userIdView?.fontSize = tableViewFontSize
        case kPremiumColumnIdentifier:
            let premiumView = view as? PremiumTableCellView
            premiumView?.premium = chat.premium
            premiumView?.fontSize = min(tableViewFontSize, kMaximumFontSizeForNonMainColumn)
        default:
            break
        }
    }

    // MARK: Utility
    private func contentAndAttributes(forMessage message: Message) -> (String, [String: Any]) {
        var content: String!
        var attributes = [String: Any]()

        if message.messageType == .system, let _message = message.message {
            content = _message
            attributes = UIHelper.normalCommentAttributes(fontSize: tableViewFontSize)
        } else if message.messageType == .chat, let _message = message.chat?.comment {
            content = _message
            if message.firstChat == true {
                attributes = UIHelper.boldCommentAttributes(fontSize: tableViewFontSize)
            } else {
                attributes = UIHelper.normalCommentAttributes(fontSize: tableViewFontSize)
            }
        }

        return (content, attributes)
    }

    // MARK: - NSControlTextEditingDelegate Functions
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let isMovedUp = commandSelector == #selector(NSResponder.moveUp(_:))
        let isMovedDown = commandSelector == #selector(NSResponder.moveDown(_:))
        if isMovedUp || isMovedDown {
            if commentHistory.count == 0 {
                // nop
            } else {
                handleCommentTextFieldKeyUpDown(isMovedUp: isMovedUp, isMovedDown: isMovedDown)
            }
            return true
        }
        return false
    }

    private func handleCommentTextFieldKeyUpDown(isMovedUp: Bool, isMovedDown: Bool) {
        if isMovedUp && 0 <= commentHistoryIndex {
            commentHistoryIndex -= 1
        } else if isMovedDown && commentHistoryIndex <= (commentHistory.count - 1) {
            commentHistoryIndex += 1
        }

        let inValidHistoryRange = (0 <= commentHistoryIndex && commentHistoryIndex <= (commentHistory.count - 1))

        commentTextField.stringValue = (inValidHistoryRange ? commentHistory[commentHistoryIndex] : "")

        // selectText() should be called in next run loop, http://stackoverflow.com/a/2196751
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.commentTextField.selectText(self)
        }
    }

    // MARK: - NicoUtilityDelegate Functions
    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtilityType) {
        DispatchQueue.main.async {
            self.connectButton.isEnabled = false
            self.progressIndicator.startAnimation(self)
        }
    }

    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtilityType, user: User, live: Live) {
        self.live = live

        DispatchQueue.main.async {
            self.liveTitleLabel.stringValue = live.title ?? ""

            let communityTitle = live.community.title ?? "-"
            let level = live.community.level != nil ? String(live.community.level ?? 0) : "-"
            self.communityTitleLabel.stringValue = communityTitle + " (Lv." + level + ")"
            self.communityIdLabel.stringValue = live.community.community ?? "-"

            let commentPlaceholder = (user.isBSP == true) ?
                "BSP Comment is not yet implemented. :P" : "⌘N (enter to comment)"
            let commentEnabled = (user.isBSP == true) ? false : true

            self.commentTextField.placeholderString = commentPlaceholder
            self.commentTextField.isEnabled = commentEnabled
            self.commentAnonymouslyButton.isEnabled = commentEnabled

            self.notificationLabel.stringValue = "Opened: ---"

            self.startTimers()
            self.loadThumbnail()
            self.focusCommentTextField()
        }

        logSystemMessageToTableView("Prepared live as user \(user.nickname ?? "").")
    }

    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtilityType, reason: String, error: NicoUtilityError?) {
        logSystemMessageToTableView("Failed to prepare live.(\(reason))")
        DispatchQueue.main.async {
            self.connectButton.isEnabled = true
            self.progressIndicator.stopAnimation(self)
        }
        showCookiePrivilegeAlertIfNeeded(error: error)
    }

    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtilityType, roomPosition: RoomPosition) {
        guard connectedToLive == false else { return }
        connectedToLive = true
        logSystemMessageToTableView("Connected to live.")
        DispatchQueue.main.async {
            self.connectButton.isEnabled = true
            self.connectButton.image = NSImage(named: kConnectButtonImageNameStop)
            self.progressIndicator.stopAnimation(self)
        }
        updateSpeechManagerState()
    }

    func nicoUtilityDidReceiveFirstChat(_ nicoUtility: NicoUtilityType, chat: Chat) {
        guard let roomPosition = chat.roomPosition else { return }

        logSystemMessageToTableView("Opened \(roomPosition.label()).")

        if let openedRoomPosition = openedRoomPosition, roomPosition.rawValue <= openedRoomPosition.rawValue {
            return
        }
        openedRoomPosition = chat.roomPosition

        DispatchQueue.main.async {
            self.notificationLabel.stringValue = "Opened: ~\(chat.roomPosition?.label() ?? "")"
        }
    }

    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtilityType, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")
        if let live = live {
            HandleNameManager.sharedManager.extractAndUpdateHandleName(live: live, chat: chat)
        }
        appendTableView(chat)

        for userWindowController in userWindowControllers where chat.userId == userWindowController.userId {
            DispatchQueue.main.async {
                userWindowController.reloadMessages()
            }
        }
    }

    func nicoUtilityDidGetKickedOut(_ nicoUtility: NicoUtilityType) {
        logSystemMessageToTableView("Got kicked out...")
    }

    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtilityType) {
        logSystemMessageToTableView("Reconnecting...")
    }

    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtilityType) {
        logSystemMessageToTableView("Live closed.")
        stopTimers()
        connectedToLive = false
        openedRoomPosition = nil
        updateSpeechManagerState()

        DispatchQueue.main.async {
            self.connectButton.image = NSImage(named: kConnectButtonImageNameStart)
        }
    }

    func nicoUtilityDidReceiveHeartbeat(_ nicoUtility: NicoUtilityType, heartbeat: Heartbeat) {
        updateLiveStatistics(heartbeat: heartbeat)
    }

    // MARK: System Message Utility
    func logSystemMessageToTableView(_ message: String) {
        appendTableView(message)
    }

    // MARK: Chat Append Utility
    private func appendTableView(_ chatOrSystemMessage: Any) {
        DispatchQueue.main.async {
            let shouldScroll = self.shouldTableViewScrollToBottom()
            let (appended, count) = MessageContainer.sharedContainer.append(chatOrSystemMessage: chatOrSystemMessage)
            guard appended else { return }
            let rowIndex = count - 1
            let message = MessageContainer.sharedContainer[rowIndex]
            self.tableView.insertRows(at: IndexSet(integer: rowIndex), withAnimation: NSTableView.AnimationOptions())
            // self.logChat(chatOrSystemMessage)
            if shouldScroll {
                self.scrollTableViewToBottom()
            }
            if message.messageType == .chat, let chat = message.chat {
                self.handleSpeech(chat: chat)
            }
            self.scrollView.flashScrollers()
        }
    }

    private func logMessage(_ message: Message) {
        var content: String?
        if message.messageType == .system {
            content = message.message
        } else if message.messageType == .chat {
            content = message.chat?.comment
        }
        log.debug("[ \(content ?? "-") ]")
    }

    private func shouldTableViewScrollToBottom() -> Bool {
        if 0 < currentScrollAnimationCount {
            return lastShouldScrollToBottom
        }

        let viewRect = scrollView.contentView.documentRect
        let visibleRect = scrollView.contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")

        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10

        let shouldScroll = (bottomY <= (offsetBottomY + allowance))
        lastShouldScrollToBottom = shouldScroll

        return shouldScroll
    }

    private func scrollTableViewToBottom(animated: Bool = false) {
        let clipView = scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        let origin = NSPoint(x: x, y: y)

        if !animated {
            // note: do not use scrollRowToVisible here.
            // scroll will be sometimes stopped when very long comment arrives.
            // tableView.scrollRowToVisible(tableView.numberOfRows - 1)
            clipView.setBoundsOrigin(origin)
        } else {
            // http://stackoverflow.com/questions/19399242/soft-scroll-animation-nsscrollview-scrolltopoint
            currentScrollAnimationCount += 1
            // log.debug("start scroll animation:\(currentScrollAnimationCount)")

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.5

            NSAnimationContext.current.completionHandler = { () -> Void in
                self.currentScrollAnimationCount -= 1
                // log.debug("  end scroll animation:\(self.currentScrollAnimationCount)")
            }

            clipView.animator().setBoundsOrigin(origin)
            // scrollView.reflectScrolledClipView(clipView)

            NSAnimationContext.endGrouping()
        }
    }

    // MARK: - UserWindowControllerDelegate Functions
    func userWindowControllerDidClose(_ userWindowController: UserWindowController) {
        log.debug("")
        if let index = userWindowControllers.firstIndex(of: userWindowController) {
            userWindowControllers.remove(at: index)
        }
    }

    // MARK: - Public Functions
    func showHandleNameAddViewController(live: Live, chat: Chat) {
        let storyboard = NSStoryboard(name: kStoryboardNameMainWindowController, bundle: nil)
        guard let handleNameAddViewController = storyboard.instantiateController(withIdentifier: kStoryboardIdHandleNameAddViewController) as? HandleNameAddViewController else {
            return
        }

        handleNameAddViewController.handleName = (defaultHandleName(live: live, chat: chat) ?? "") as NSString
        handleNameAddViewController.completion = { (cancelled: Bool, handleName: String?) -> Void in
            if !cancelled, let handleName = handleName {
                HandleNameManager.sharedManager.updateHandleName(live: live, chat: chat, handleName: handleName)
                MainViewController.shared.refreshHandleName()
            }

            self.dismiss(handleNameAddViewController)
            // TODO: deinit in handleNameViewController is not called after this completion
        }

        presentAsSheet(handleNameAddViewController)
    }

    private func defaultHandleName(live: Live, chat: Chat) -> String? {
        var defaultHandleName: String?
        if let handleName = HandleNameManager.sharedManager.handleName(forLive: live, chat: chat) {
            defaultHandleName = handleName
        } else if let userName = NicoUtility.shared.cachedUserName(forChat: chat) {
            defaultHandleName = userName
        }
        return defaultHandleName
    }

    func refreshHandleName() {
        tableView.reloadData()
        scrollView.flashScrollers()
    }

    // MARK: Hotkeys
    func focusLiveTextField() {
        liveTextField.becomeFirstResponder()
    }

    func focusCommentTextField() {
        commentTextField.becomeFirstResponder()
    }

    // MARK: - Internal Functions
    private func initializeHandleNameManager() {
        progressIndicator.startAnimation(self)
        // force to invoke setup methods in HandleNameManager()
        _ = HandleNameManager.sharedManager
        progressIndicator.stopAnimation(self)
    }

    // MARK: Live Info Updater
    private func loadThumbnail() {
        NicoUtility.shared.loadThumbnail { (imageData) -> Void in
            DispatchQueue.main.async {
                guard let data = imageData else { return }
                self.communityImageView.image = NSImage(data: data)
            }
        }
    }

    private func updateLiveStatistics(heartbeat: Heartbeat) {
        guard heartbeat.status == .ok,
              let watchCount = heartbeat.watchCount,
              let commentCount = heartbeat.commentCount else { return }

        let visitors = String(watchCount).numberStringWithSeparatorComma()
        let comments = String(commentCount).numberStringWithSeparatorComma()

        var remaining = "-"
        if let free = heartbeat.freeSlotNum {
            remaining = free == 0 ? "満員" : String(free).numberStringWithSeparatorComma()
        }

        DispatchQueue.main.async {
            self.visitorsLabel.stringValue = "Visitors: " + visitors
            self.commentsLabel.stringValue = "Comments: " + comments
            self.remainingSeatsLabel.stringValue = "Seats: " + remaining
        }
    }

    // MARK: Control Handlers
    @IBAction func grabUrlFromBrowser(_ sender: AnyObject) {
        guard let session = SessionManagementType(rawValue:
                                                    UserDefaults.standard.integer(forKey: Parameters.sessionManagement)) else { return }
        let browser: BrowserHelper.BrowserType = session == .safari ? .safari : .chrome
        if let url = BrowserHelper.extractUrl(fromBrowser: browser) {
            liveTextField.stringValue = url
            connectLive(self)
        }
    }

    @IBAction func connectLive(_ sender: AnyObject) {
        initializeHandleNameManager()
        guard let liveNumber = liveTextField.stringValue.extractLiveNumber() else { return }

        clearAllChats()
        communityImageView.image = NSImage(named: kCommunityImageDefaultName)
        NicoUtility.shared.delegate = self

        guard let sessionManagementType = SessionManagementType(
                rawValue: UserDefaults.standard.integer(forKey: Parameters.sessionManagement)) else { return }

        let connectType = { () -> NicoConnectType? in
            switch sessionManagementType {
            case .login:
                guard let account = KeychainUtility.accountInKeychain() else { return nil }
                return .login(mail: account.mailAddress, password: account.password)
            case .chrome:
                return .chrome
            case .safari:
                return .safari
            }
        }()

        guard let connectType = connectType else { return }
        NicoUtility.shared.connect(liveNumber: liveNumber, connectType: connectType)
    }

    @IBAction func connectButtonPressed(_ sender: AnyObject) {
        if connectedToLive {
            NicoUtility.shared.disconnect()
        } else {
            connectLive(self)
        }
    }

    @IBAction func comment(_ sender: AnyObject) {
        let comment = commentTextField.stringValue
        guard 0 < comment.count else { return }

        let anonymously = UserDefaults.standard.bool(forKey: Parameters.commentAnonymously)
        NicoUtility.shared.comment(comment, anonymously: anonymously) { comment in
            if comment == nil {
                self.logSystemMessageToTableView("Failed to comment.")
            }
        }
        commentTextField.stringValue = ""

        if commentHistory.count == 0 || commentHistory.last != comment {
            commentHistory.append(comment)
            commentHistoryIndex = commentHistory.count
        }
    }

    @objc func openUserWindow(_ sender: AnyObject?) {
        let clickedRow = tableView.clickedRow
        if clickedRow == -1 {
            return
        }

        let message = MessageContainer.sharedContainer[clickedRow]
        guard message.messageType == .chat, let chat = message.chat, let userId = chat.userId else { return }
        var userWindowController: UserWindowController?

        // check if user window exists?
        for existing in userWindowControllers where userId == existing.userId {
            userWindowController = existing
            log.debug("existing userwc found, use it:\(userWindowController?.description ?? "")")
            break
        }

        if userWindowController == nil {
            // not exist, so create and cache it
            userWindowController = UserWindowController.generateInstance(delegate: self, userId: userId)
            if let uwc = userWindowController {
                positionUserWindow(uwc.window)
                log.debug("no existing userwc found, create it:\(uwc.description)")
                userWindowControllers.append(uwc)
            }
        }
        userWindowController?.showWindow(self)
    }

    private func positionUserWindow(_ userWindow: NSWindow?) {
        guard let userWindow = userWindow else { return }
        var topLeftPoint: NSPoint = nextUserWindowTopLeftPoint
        if userWindowControllers.count == 0 {
            topLeftPoint = kUserWindowDefautlTopLeftPoint
        }
        nextUserWindowTopLeftPoint = userWindow.cascadeTopLeft(from: topLeftPoint)
    }

    // MARK: Timer Functions
    private func startTimers() {
        elapsedTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(MainViewController.displayElapsed(_:)), userInfo: nil, repeats: true)
        activeTimer = Timer.scheduledTimer(timeInterval: kCalculateActiveInterval, target: self, selector: #selector(MainViewController.calculateActive(_:)), userInfo: nil, repeats: true)
    }

    private func stopTimers() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        activeTimer?.invalidate()
        activeTimer = nil
    }

    @objc func displayElapsed(_ timer: Timer) {
        var display = "--:--:--"

        if let startTime = NicoUtility.shared.live?.startTime {
            var prefix = ""
            var elapsed = Date().timeIntervalSince(startTime as Date)
            if elapsed < 0 {
                prefix = "-"
                elapsed = abs(elapsed)
            }
            let hour = String(format: "%02d", Int(elapsed / 3600))
            let minute = String(format: "%02d", Int((elapsed / 60).truncatingRemainder(dividingBy: 60)))
            let second = String(format: "%02d", Int(elapsed.truncatingRemainder(dividingBy: 60)))
            display = "\(prefix)\(hour):\(minute):\(second)"
        }

        DispatchQueue.main.async {
            self.elapsedLabel.stringValue = "Elapsed: " + display
        }
    }

    @objc func calculateActive(_ timer: Timer) {
        MessageContainer.sharedContainer.calculateActive { (active: Int?) -> Void in
            guard let activeCount = active else { return }
            DispatchQueue.main.async {
                self.activeLabel.stringValue = "Active: \(activeCount)"
            }
        }
    }

    // MARK: Speech Handlers
    private func updateSpeechManagerState() {
        let enabled = UserDefaults.standard.bool(forKey: Parameters.enableCommentSpeech)

        if enabled && connectedToLive {
            SpeechManager.sharedManager.startManager()
        } else {
            SpeechManager.sharedManager.stopManager()
        }
    }

    private func handleSpeech(chat: Chat) {
        let enabled = UserDefaults.standard.bool(forKey: Parameters.enableCommentSpeech)
        guard enabled else { return }
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            SpeechManager.sharedManager.enqueue(chat: chat)
            if SpeechManager.sharedManager.refreshChatQueueIfQueuedTooMuch() {
                // logSystemMessageToTableView("Refreshed speech queue.")
            }
        }
    }

    // MARK: Misc Utility
    private func clearAllChats() {
        MessageContainer.sharedContainer.removeAll()
        rowHeightCacher.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }
}

// Alert view for Safari cookie
private extension MainViewController {
    func showCookiePrivilegeAlertIfNeeded(error: NicoUtilityError?) {
        guard error == .noCookieFound else { return }
        let param = UserDefaults.standard.integer(forKey: Parameters.sessionManagement)
        guard let sessionManagementType = SessionManagementType(rawValue: param) else { return }
        switch sessionManagementType {
        case .safari:
            let alert = NSAlert()
            alert.messageText = safariCookieAlertTitle
            alert.informativeText = safariCookieAlertDescription
            if let image = NSImage(named: safariCookieAlertImageName) {
                let imageView = NSImageView(image: image)
                imageView.frame = NSRect.init(x: 0, y: 0, width: 300, height: 300)
                alert.accessoryView = imageView
            }
            let securityButton = alert.addButton(withTitle: "Open Security & Privacy")
            securityButton.target = self
            securityButton.action = #selector(MainViewController.showSecurityPanel)
            alert.addButton(withTitle: "Cancel")
            alert.runModal()
        default:
            break
        }
    }

    @objc func showSecurityPanel() {
        let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
        NSWorkspace.shared.open(url)
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
// swiftlint:enable file_length
