//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import Kingfisher

private let userWindowDefautlTopLeftPoint = NSPoint(x: 100, y: 100)
private let calculateActiveUserInterval: TimeInterval = 5
private let maximumFontSizeForNonMainColumn: CGFloat = 16
private let defaultMinimumRowHeight: CGFloat = 17

private let enableDebugButtons = true

private let defaultElapsedTimeValue = "--:--:--"
private let defaultLabelValue = "---"

// swiftlint:disable file_length
final class MainViewController: NSViewController {
    // MARK: Types
    enum ConnectionStatus { case disconnected, connecting, connected }

    // MARK: Properties
    static var shared: MainViewController!

    // MARK: Main Outlets
    @IBOutlet private weak var grabUrlButton: NSButton!
    @IBOutlet private weak var liveUrlTextField: NSTextField!
    @IBOutlet private weak var debugReconnectButton: NSButton!
    @IBOutlet private weak var connectButton: NSButton!

    @IBOutlet private weak var communityImageView: NSImageView!
    @IBOutlet private weak var liveTitleLabel: NSTextField!
    @IBOutlet private weak var communityTitleLabel: NSTextField!
    @IBOutlet private weak var communityIdLabel: NSTextField!

    @IBOutlet private weak var visitorsTitleLabel: NSTextField!
    @IBOutlet private weak var visitorsValueLabel: NSTextField!
    @IBOutlet private weak var commentsTitleLabel: NSTextField!
    @IBOutlet private weak var commentsValueLabel: NSTextField!
    @IBOutlet private weak var speakButton: NSButton!

    @IBOutlet private weak var scrollView: BottomButtonScrollView!
    @IBOutlet private(set) weak var tableView: NSTableView!

    @IBOutlet private weak var commentTextField: NSTextField!
    @IBOutlet private weak var commentAnonymouslyButton: NSButton!

    @IBOutlet private weak var elapsedTimeTitleLabel: NSTextField!
    @IBOutlet private weak var elapsedTimeValueLabel: NSTextField!
    @IBOutlet private weak var activeUserTitleLabel: NSTextField!
    @IBOutlet private weak var activeUserValueLabel: NSTextField!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    // MARK: Menu Delegate
    // swiftlint:disable weak_delegate
    @IBOutlet var menuDelegate: MenuDelegate!
    // swiftlint:enable weak_delegate

    // MARK: General Properties
    private(set) var live: Live?
    private var connectedToLive = false
    private var chats = [Chat]()
    private var liveStartedDate: Date?

    // row-height cache
    private var rowHeightCacher = [Int: CGFloat]()
    private var minimumRowHeight: CGFloat = defaultMinimumRowHeight
    private var tableViewFontSize: CGFloat = CGFloat(kDefaultFontSize)

    private var commentHistory = [String]()
    private var commentHistoryIndex: Int = 0

    private var elapsedTimeTimer: Timer?
    private var activeUserTimer: Timer?

    // AuthWindowController
    private var authWindowController: AuthWindowController?

    // UserWindowControllers
    private var userWindowControllers = [UserWindowController]()
    private var nextUserWindowTopLeftPoint: NSPoint = NSPoint.zero
}

// MARK: - Object Lifecycle
extension MainViewController {
    override func awakeFromNib() {
        super.awakeFromNib()

        MainViewController.shared = self
    }
}

// MARK: - NSViewController Functions
extension MainViewController {
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        DispatchQueue.main.async { self.focusLiveTextField() }
    }

    override func viewDidAppear() {
        // kickTableViewStressTest()
        // updateStandardUserDefaults()
    }
}

// MARK: - NSTableViewDataSource Functions
extension MainViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return MessageContainer.shared.count()
    }
}

// MARK: - NSTableViewDelegate Functions
extension MainViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = MessageContainer.shared[row]

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

        let message = MessageContainer.shared[row]

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
            let commentView = view as? CommentTableCellView
            let (content, attributes) = contentAndAttributes(forMessage: message)
            let attributed = NSAttributedString(string: content, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
            commentView?.attributedString = attributed
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
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = chat.roomPosition
            roomPositionView?.commentNo = chat.no
            roomPositionView?.fontSize = min(tableViewFontSize, maximumFontSizeForNonMainColumn)
        case kScoreColumnIdentifier:
            let scoreView = view as? ScoreTableCellView
            scoreView?.chat = chat
            scoreView?.fontSize = min(tableViewFontSize, maximumFontSizeForNonMainColumn)
        case kCommentColumnIdentifier:
            let commentView = view as? CommentTableCellView
            let (content, attributes) = contentAndAttributes(forMessage: message)
            let attributed = NSAttributedString(string: content as String, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
            commentView?.attributedString = attributed
        case kUserIdColumnIdentifier:
            guard let live = live else { return }
            let userIdView = view as? UserIdTableCellView
            let handleName = HandleNameManager.shared.handleName(forLive: live, chat: chat)
            userIdView?.info = (handleName: handleName, userId: chat.userId, premium: chat.premium, comment: chat.comment)
            userIdView?.fontSize = tableViewFontSize
        case kPremiumColumnIdentifier:
            let premiumView = view as? PremiumTableCellView
            premiumView?.premium = chat.premium
            premiumView?.fontSize = min(tableViewFontSize, maximumFontSizeForNonMainColumn)
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
}

// MARK: - NSControlTextEditingDelegate Functions
extension MainViewController: NSControlTextEditingDelegate {
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
}

// MARK: - AuthWindowControllerDelegate Functions
extension MainViewController: AuthWindowControllerDelegate {
    func authWindowControllerDidLogin(_ authWindowController: AuthWindowController) {
        logSystemMessageToTableView(L10n.loginCompleted)
    }
}

// MARK: - NicoUtilityDelegate Functions
extension MainViewController: NicoUtilityDelegate {
    func nicoUtilityNeedsLogin(_ nicoUtility: NicoUtilityType) {
        showAuthWindowController()
    }

    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtilityType) {
        updateMainControlViews(status: .connecting)
    }

    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtilityType, user: User, live: Live, connectContext: NicoUtility.ConnectContext) {
        self.live = live

        updateCommunityViews(for: live)
        startTimers()
        focusCommentTextField()

        switch connectContext {
        case .normal:
            logSystemMessageToTableView(L10n.preparedLive(user.nickname))
        case .reconnect:
            break
        }
    }

    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtilityType, error: NicoUtility.NicoError) {
        logSystemMessageToTableView(L10n.failedToPrepareLive(error.toMessage))
        updateMainControlViews(status: .disconnected)
    }

    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtilityType, roomPosition: RoomPosition, connectContext: NicoUtility.ConnectContext) {
        guard connectedToLive == false else { return }
        connectedToLive = true
        switch connectContext {
        case .normal:
            liveStartedDate = Date()
            logSystemMessageToTableView(L10n.connectedToLive)
        case .reconnect:
            break
        }
        updateMainControlViews(status: .connected)
        updateSpeechManagerState()
    }

    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtilityType, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")
        if let live = live {
            HandleNameManager.shared.extractAndUpdateHandleName(live: live, chat: chat)
        }
        appendTableView(chat)

        for userWindowController in userWindowControllers where chat.userId == userWindowController.userId {
            DispatchQueue.main.async {
                userWindowController.reloadMessages()
            }
        }
    }

    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtilityType, reason: NicoUtility.ReconnectReason) {
        switch reason {
        case .normal:
            logSystemMessageToTableView(L10n.reconnecting)
        case .noPong, .noTexts:
            break
        }
    }

    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtilityType, disconnectContext: NicoUtility.DisconnectContext) {
        switch disconnectContext {
        case .normal:
            logSystemMessageToTableView(L10n.liveClosed)
        case .reconnect:
            break
        }
        stopTimers()
        connectedToLive = false
        updateSpeechManagerState()

        switch disconnectContext {
        case .normal:       updateMainControlViews(status: .disconnected)
        case .reconnect:    updateMainControlViews(status: .connecting)
        }
    }

    func nicoUtilityDidReceiveStatistics(_ nicoUtility: NicoUtilityType, stat: LiveStatistics) {
        updateLiveStatistics(stat: stat)
    }
}

// MARK: - UserWindowControllerDelegate Functions
extension MainViewController: UserWindowControllerDelegate {
    func userWindowControllerDidClose(_ userWindowController: UserWindowController) {
        log.debug("")
        if let index = userWindowControllers.firstIndex(of: userWindowController) {
            userWindowControllers.remove(at: index)
        }
    }
}

// MARK: - Public Functions
extension MainViewController {
    func login() {
        showAuthWindowController()
        // login message will be displayed from `authWindowControllerDidLogin()` delegate method.
    }

    func logout() {
        if connectedToLive {
            NicoUtility.shared.disconnect()
        }
        NicoUtility.shared.logout()
        authWindowController?.logout()
        authWindowController = nil
        logSystemMessageToTableView(L10n.logoutCompleted)
    }

    func showHandleNameAddViewController(live: Live, chat: Chat) {
        let handleNameAddViewController =
            StoryboardScene.MainWindowController.handleNameAddViewController.instantiate()
        handleNameAddViewController.handleName = (defaultHandleName(live: live, chat: chat) ?? "") as NSString
        handleNameAddViewController.completion = { (cancelled: Bool, handleName: String?) -> Void in
            if !cancelled, let handleName = handleName {
                HandleNameManager.shared.updateHandleName(live: live, chat: chat, handleName: handleName)
                MainViewController.shared.refreshHandleName()
            }

            self.dismiss(handleNameAddViewController)
            // TODO: deinit in handleNameViewController is not called after this completion
        }

        presentAsSheet(handleNameAddViewController)
    }

    private func defaultHandleName(live: Live, chat: Chat) -> String? {
        var defaultHandleName: String?
        if let handleName = HandleNameManager.shared.handleName(forLive: live, chat: chat) {
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
        liveUrlTextField.becomeFirstResponder()
    }

    func focusCommentTextField() {
        commentTextField.becomeFirstResponder()
    }
}

// MARK: Utility
extension MainViewController {
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
        MessageContainer.shared.enableMuteUserIds = enabled
        log.debug("changed enable mute userids: \(enabled)")
        rebuildFilteredMessages()
    }

    func changeMuteUserIds(_ muteUserIds: [[String: String]]) {
        MessageContainer.shared.muteUserIds = muteUserIds
        log.debug("changed mute userids: \(muteUserIds)")
        rebuildFilteredMessages()
    }

    func changeEnableMuteWords(_ enabled: Bool) {
        MessageContainer.shared.enableMuteWords = enabled
        log.debug("changed enable mute words: \(enabled)")
        rebuildFilteredMessages()
    }

    func changeMuteWords(_ muteWords: [[String: String]]) {
        MessageContainer.shared.muteWords = muteWords
        log.debug("changed mute words: \(muteWords)")
        rebuildFilteredMessages()
    }

    private func rebuildFilteredMessages() {
        DispatchQueue.main.async {
            self.progressIndicator.startAnimation(self)
            let shouldScroll = self.scrollView.isReachedToBottom
            MessageContainer.shared.rebuildFilteredMessages {
                self.tableView.reloadData()
                if shouldScroll {
                    self.scrollView.scrollToBottom()
                }
                self.scrollView.flashScrollers()
                self.progressIndicator.stopAnimation(self)
            }
        }
    }
}

// MARK: Chat Message Utility (Internal)
extension MainViewController {
    func logSystemMessageToTableView(_ message: String) {
        appendTableView(message)
    }
}

// MARK: Configure Views
private extension MainViewController {
    func configureViews() {
        communityImageView.addBorder()
        [debugReconnectButton].forEach {
            $0?.isHidden = !enableDebugButtons
        }

        liveUrlTextField.placeholderString = L10n.liveUrlTextFieldPlaceholder

        liveTitleLabel.stringValue = "[\(L10n.liveTitle)]"
        communityIdLabel.stringValue = "[\(L10n.communityId)]"
        communityTitleLabel.stringValue = "[\(L10n.communityName)]"

        visitorsTitleLabel.stringValue = "\(L10n.visitorCount):"
        visitorsValueLabel.stringValue = defaultLabelValue
        commentsTitleLabel.stringValue = "\(L10n.commentCount):"
        commentsValueLabel.stringValue = defaultLabelValue
        speakButton.title = L10n.speakComment

        if #available(macOS 10.14, *) {
            speakButton.isHidden = false
        } else {
            speakButton.isHidden = true
        }

        commentTextField.placeholderString = L10n.commentTextFieldPlaceholder

        elapsedTimeTitleLabel.stringValue = "\(L10n.elapsedTime):"
        elapsedTimeValueLabel.stringValue = defaultElapsedTimeValue
        activeUserTitleLabel.stringValue = "\(L10n.activeUser):"
        activeUserValueLabel.stringValue = defaultLabelValue

        scrollView.enableBottomScrollButton()
        configureTableView()
        registerNibs()
    }

    func configureTableView() {
        tableView.doubleAction = #selector(MainViewController.openUserWindow(_:))
    }

    func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameScoreTableCellView, kScoreColumnIdentifier),
            (kNibNameCommentTableCellView, kCommentColumnIdentifier),
            (kNibNameUserIdTableCellView, kUserIdColumnIdentifier),
            (kNibNamePremiumTableCellView, kPremiumColumnIdentifier)]

        for (nibName, identifier) in nibs {
            guard let nib = NSNib(nibNamed: nibName, bundle: Bundle.main) else { continue }
            tableView.register(nib, forIdentifier: convertToNSUserInterfaceItemIdentifier(identifier))
        }
    }

    func updateMainControlViews(status connectionStatus: ConnectionStatus) {
        DispatchQueue.main.async { self._updateMainControlViews(status: connectionStatus) }
    }

    func _updateMainControlViews(status connectionStatus: ConnectionStatus) {
        let controls: [NSControl] = [grabUrlButton, liveUrlTextField, connectButton]
        switch connectionStatus {
        case .disconnected:
            controls.forEach { $0.isEnabled = true }
            connectButton.image = Asset.startLive.image
            progressIndicator.stopAnimation(self)
        case .connecting:
            controls.forEach { $0.isEnabled = false }
            progressIndicator.startAnimation(self)
        case .connected:
            controls.forEach { $0.isEnabled = true }
            connectButton.image = Asset.stopLive.image
            progressIndicator.stopAnimation(self)
        }
    }

    func updateCommunityViews(for live: Live) {
        DispatchQueue.main.async { self._updateCommunityViews(for: live) }
    }

    func _updateCommunityViews(for live: Live) {
        if let url = live.community?.thumbnailUrl {
            communityImageView.kf.setImage(
                with: url,
                placeholder: Asset.defaultCommunityImage.image
            )
        }
        liveTitleLabel.stringValue = live.title
        communityIdLabel.stringValue = live.community?.communityId ?? "-"
        var communityTitle = live.community?.title ?? "-"
        if let level = live.community?.level {
            communityTitle += " (Lv.\(level))"
        }
        communityTitleLabel.stringValue = communityTitle
    }
}

// MARK: Chat Message Utility (Private)
private extension MainViewController {
    func appendTableView(_ chatOrSystemMessage: Any) {
        DispatchQueue.main.async {
            let shouldScroll = self.scrollView.isReachedToBottom
            let (appended, count) = MessageContainer.shared.append(chatOrSystemMessage: chatOrSystemMessage)
            guard appended else { return }
            let rowIndex = count - 1
            let message = MessageContainer.shared[rowIndex]
            self.tableView.insertRows(at: IndexSet(integer: rowIndex), withAnimation: NSTableView.AnimationOptions())
            // self.logChat(chatOrSystemMessage)
            if shouldScroll {
                self.scrollView.scrollToBottom()
            }
            if message.messageType == .chat, let chat = message.chat {
                self.handleSpeech(chat: chat)
            }
            self.scrollView.flashScrollers()
        }
    }

    func logMessage(_ message: Message) {
        var content: String?
        if message.messageType == .system {
            content = message.message
        } else if message.messageType == .chat {
            content = message.chat?.comment
        }
        log.debug("[ \(content ?? "-") ]")
    }
}

// MARK: - Internal Functions
private extension MainViewController {
    func initializeHandleNameManager() {
        progressIndicator.startAnimation(self)
        // force to invoke setup methods in HandleNameManager()
        _ = HandleNameManager.shared
        progressIndicator.stopAnimation(self)
    }

    // MARK: Live Info Updater
    func updateLiveStatistics(stat: LiveStatistics) {
        let visitors = String(stat.viewers).numberStringWithSeparatorComma()
        let comments = String(stat.comments).numberStringWithSeparatorComma()
        DispatchQueue.main.async {
            self.visitorsValueLabel.stringValue = visitors
            self.commentsValueLabel.stringValue = comments
        }
    }
}

// MARK: Control Handlers
extension MainViewController {
    @IBAction func grabUrlFromBrowser(_ sender: AnyObject) {
        let rawValue = UserDefaults.standard.integer(forKey: Parameters.browserInUse)
        guard let _browser = BrowserInUseType(rawValue: rawValue) else { return }
        let browser: BrowserHelper.BrowserType = {
            switch _browser {
            case .chrome:   return .chrome
            case .safari:   return .safari
            }
        }()
        guard let url = BrowserHelper.extractUrl(fromBrowser: browser) else { return }
        liveUrlTextField.stringValue = url
        connectLive(self)
    }

    @IBAction func debugReconnectButtonPressed(_ sender: Any) {
        let reason: NicoUtility.ReconnectReason
        reason = .normal
        // reason = .noPong
        // reason = .noTexts
        NicoUtility.shared.reconnect(reason: reason)
    }

    @IBAction func connectLive(_ sender: AnyObject) {
        initializeHandleNameManager()
        guard let liveProgramId = liveUrlTextField.stringValue.extractLiveProgramId() else { return }

        clearAllChats()
        communityImageView.image = Asset.defaultCommunityImage.image
        NicoUtility.shared.delegate = self

        NicoUtility.shared.connect(liveProgramId: liveProgramId)
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

        if comment.isEmpty {
            scrollView.scrollToBottom()
            scrollView.flashScrollers()
            return
        }

        let anonymously = UserDefaults.standard.bool(forKey: Parameters.commentAnonymously)
        NicoUtility.shared.comment(comment, anonymously: anonymously) { comment in
            if comment == nil {
                self.logSystemMessageToTableView(L10n.failedToComment)
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

        let message = MessageContainer.shared[clickedRow]
        guard message.messageType == .chat, let chat = message.chat else { return }
        var userWindowController: UserWindowController?

        // check if user window exists?
        for existing in userWindowControllers where chat.userId == existing.userId {
            userWindowController = existing
            log.debug("existing userwc found, use it:\(userWindowController?.description ?? "")")
            break
        }

        if userWindowController == nil {
            // not exist, so create and cache it
            var handleName: String?
            if let live = live,
               let _handleName = HandleNameManager.shared.handleName(forLive: live, chat: chat) {
                handleName = _handleName
            }
            userWindowController = UserWindowController.make(
                delegate: self, userId: chat.userId, handleName: handleName)
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
            topLeftPoint = userWindowDefautlTopLeftPoint
        }
        nextUserWindowTopLeftPoint = userWindow.cascadeTopLeft(from: topLeftPoint)
    }
}

// MARK: Timer Functions
private extension MainViewController {
    func startTimers() {
        elapsedTimeTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(MainViewController.updateElapsedLabelValue),
            userInfo: nil,
            repeats: true)
        activeUserTimer = Timer.scheduledTimer(
            timeInterval: calculateActiveUserInterval,
            target: self,
            selector: #selector(MainViewController.calculateAndUpdateActiveUserLabel),
            userInfo: nil,
            repeats: true)
    }

    func stopTimers() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
        activeUserTimer?.invalidate()
        activeUserTimer = nil
    }

    @objc func updateElapsedLabelValue() {
        var display = defaultElapsedTimeValue

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

        DispatchQueue.main.async { self.elapsedTimeValueLabel.stringValue = display }
    }

    @objc func calculateAndUpdateActiveUserLabel() {
        MessageContainer.shared.calculateActive { (active: Int?) -> Void in
            guard let active = active else { return }
            DispatchQueue.main.async { self.activeUserValueLabel.stringValue = String(active) }
        }
    }
}

// MARK: Speech Handlers
private extension MainViewController {
    func updateSpeechManagerState() {
        guard #available(macOS 10.14, *) else { return }
        let enabled = UserDefaults.standard.bool(forKey: Parameters.enableCommentSpeech)

        if enabled && connectedToLive {
            SpeechManager.shared.startManager()
        } else {
            SpeechManager.shared.stopManager()
        }
    }

    func handleSpeech(chat: Chat) {
        guard #available(macOS 10.14, *) else { return }
        let enabled = UserDefaults.standard.bool(forKey: Parameters.enableCommentSpeech)
        guard enabled else { return }
        guard let started = liveStartedDate,
              Date().timeIntervalSince(started) > 5 else {
            // Skip enqueuing since there's possibility that we receive lots of
            // messages for this time slot.
            log.debug("Skip enqueuing early chats.")
            return
        }
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            SpeechManager.shared.enqueue(chat: chat)
            if SpeechManager.shared.refreshChatQueueIfQueuedTooMuch() {
                // logSystemMessageToTableView("Refreshed speech queue.")
            }
        }
    }
}

// MARK: Misc Utility
private extension MainViewController {
    func clearAllChats() {
        MessageContainer.shared.removeAll()
        rowHeightCacher.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }

    func showAuthWindowController() {
        if authWindowController == nil {
            authWindowController = AuthWindowController.make(delegate: self)
        }
        authWindowController?.startAuthorization()
        authWindowController?.showWindow(self)
    }
}

private extension NicoUtility.NicoError {
    var toMessage: String {
        switch self {
        case .internal:                     return L10n.errorInternal
        case .noLiveInfo:                   return L10n.errorNoLiveInfo
        case .noMessageServerInfo:          return L10n.errorNoMessageServerInfo
        case .failedToOpenMessageServer:    return L10n.errorFailedToOpenMessageServer
        }
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
