//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import Charts
import Kingfisher

private let userWindowDefaultTopLeftPoint = NSPoint(x: 100, y: 100)
private let calculateActiveUserInterval: TimeInterval = 5
private let maximumFontSizeForNonMainColumn: CGFloat = 16
private let defaultMinimumRowHeight: CGFloat = 17

private let enableDebugButtons = false

private let defaultElapsedTimeValue = "--:--:--"
private let defaultLabelValue = "---"
private let defaultChartText = "-----"
private let defaultRankDateText = "--:--"

// swiftlint:disable file_length
protocol MainViewControllerDelegate: AnyObject {
    func mainViewControllerDidPrepareLive(_ mainViewController: MainViewController, title: String, community: String)
}

final class MainViewController: NSViewController {
    // MARK: Types
    enum ConnectionStatus { case disconnected, connecting, connected }

    // MARK: Properties
    static var shared: MainViewController!
    weak var delegate: MainViewControllerDelegate?

    // MARK: Main Outlets
    @IBOutlet private weak var grabUrlButton: NSButton!
    @IBOutlet private weak var liveUrlTextField: NSTextField!
    @IBOutlet private weak var debugReconnectButton: NSButton!
    @IBOutlet private weak var debugExpireTokenButton: NSButton!
    @IBOutlet private weak var connectButton: NSButton!

    @IBOutlet private weak var communityImageView: NSImageView!
    @IBOutlet private weak var liveTitleLabel: NSTextField!
    @IBOutlet private weak var communityTitleLabel: NSTextField!

    @IBOutlet private weak var visitorsIconImageView: NSImageView!
    @IBOutlet private weak var visitorsValueLabel: NSTextField!
    @IBOutlet private weak var commentsIconImageView: NSImageView!
    @IBOutlet private weak var commentsValueLabel: NSTextField!
    @IBOutlet private weak var adPointsIconImageView: NSImageView!
    @IBOutlet private weak var adPointsValueLabel: NSTextField!
    @IBOutlet private weak var giftPointsIconImageView: NSImageView!
    @IBOutlet private weak var giftPointsLabel: NSTextField!
    @IBOutlet private weak var speakButton: NSButton!

    @IBOutlet private weak var scrollView: ButtonScrollView!
    @IBOutlet private(set) weak var tableView: ClickTableView!

    @IBOutlet private weak var commentTextField: NSTextField!
    @IBOutlet private weak var commentAnonymouslyButton: NSButton!

    @IBOutlet private weak var elapsedTimeIconImageView: NSImageView!
    @IBOutlet private weak var elapsedTimeValueLabel: NSTextField!
    @IBOutlet private weak var activeUserIconImageView: NSImageView!
    @IBOutlet private weak var activeUserValueLabel: NSTextField!
    @IBOutlet private weak var maxActiveUserValueLabel: NSTextField!
    @IBOutlet private weak var activeUserChartView: LineChartView!
    @IBOutlet private weak var rankingIconImageView: NSImageView!
    @IBOutlet private weak var rankingValueLabel: NSTextField!
    @IBOutlet private weak var rankingDateLabel: NSTextField!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    // MARK: Menu Delegate
    // swiftlint:disable weak_delegate
    @IBOutlet var menuDelegate: MenuDelegate!
    // swiftlint:enable weak_delegate

    // MARK: General Properties
    let nicoManager: NicoManagerType = NicoManager()
    let messageContainer = MessageContainer()
    let speechManager = SpeechManager()
    let rankingManager: RankingManagerType = RankingManager.shared

    private(set) var live: Live?
    private var connectedToLive = false
    private var chats = [Chat]()
    private var liveStartedDate: Date?

    // row-height cache
    private var rowHeightCache = [Int: CGFloat]()
    private var minimumRowHeight: CGFloat = defaultMinimumRowHeight
    private var tableViewFontSize: CGFloat = CGFloat(kDefaultFontSize)

    private var commentHistory = [String]()
    private var commentHistoryIndex: Int = 0

    private var elapsedTimeTimer: Timer?
    private var activeUserTimer: Timer?
    private var rankingTimer: Timer?

    private var activeUserCount = 0
    private var maxActiveUserCount = 0
    private var activeUserHistory: [(Date, Int)] = []

    // AuthWindowController
    private lazy var authWindowController: AuthWindowController = {
        AuthWindowController.make(delegate: self)
    }()

    // UserWindowControllers
    private var userWindowControllers = [UserWindowController]()
    private var nextUserWindowTopLeftPoint: NSPoint = NSPoint.zero

    // Debug
    private var logDebugInfo = false

    deinit { log.debug("deinit") }
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
        configureManagers()
        configureMute()
        configureFontSize()
        configureAnonymouslyButton()
        configureDebugLogInfo()
        DispatchQueue.main.async { self.focusLiveTextField() }
    }
}

// MARK: - NSTableViewDataSource Functions
extension MainViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        messageContainer.count()
    }
}

// MARK: - NSTableViewDelegate Functions
extension MainViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = messageContainer[row]

        if let cached = rowHeightCache[message.messageNo] {
            return cached
        }

        var rowHeight: CGFloat = 0

        guard let commentTableColumn = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: kCommentColumnIdentifier)) else { return rowHeight }
        let commentColumnWidth = commentTableColumn.width
        rowHeight = commentColumnHeight(forMessage: message, width: commentColumnWidth)

        rowHeightCache[message.messageNo] = rowHeight

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

        let iconHeight = message.chat?.hasUserIcon == true ? iconColumnWidth : 0
        return max(iconHeight, max(commentRect.size.height, minimumRowHeight))
    }

    private var iconColumnWidth: CGFloat {
        let iconColumnId = NSUserInterfaceItemIdentifier(kIconColumnIdentifier)
        return tableView.tableColumn(withIdentifier: iconColumnId)?.width ?? 0
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
        switch column.identifier.rawValue {
        case kIconColumnIdentifier, kCommentColumnIdentifier:
            rowHeightCache.removeAll(keepingCapacity: false)
            tableView.reloadData()
        default:
            break
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var view: NSTableCellView?

        if let identifier = tableColumn?.identifier {
            view = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            view?.textField?.stringValue = ""
        }

        let message = messageContainer[row]

        guard let _view = view, let tableColumn = tableColumn else { return nil }

        if message.messageType == .system {
            configure(view: _view, forSystemMessage: message, withTableColumn: tableColumn)
        } else if message.messageType == .chat {
            configure(view: _view, forChat: message, withTableColumn: tableColumn)
        }

        return view
    }

    private func configure(view: NSTableCellView, forSystemMessage message: Message, withTableColumn tableColumn: NSTableColumn) {
        switch tableColumn.identifier.rawValue {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = nil
            roomPositionView?.commentNo = nil
            roomPositionView?.fontSize = nil
        case kTimeColumnIdentifier:
            let timeView = view as? TimeTableCellView
            timeView?.configure(live: nil, chat: nil)
            timeView?.fontSize = nil
        case kIconColumnIdentifier:
            let iconView = view as? IconTableCellView
            iconView?.configure(iconType: .none)
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

        switch tableColumn.identifier.rawValue {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = chat.roomPosition
            roomPositionView?.commentNo = chat.no
            roomPositionView?.fontSize = min(tableViewFontSize, maximumFontSizeForNonMainColumn)
        case kTimeColumnIdentifier:
            let timeView = view as? TimeTableCellView
            timeView?.configure(live: live, chat: chat)
            timeView?.fontSize = min(tableViewFontSize, maximumFontSizeForNonMainColumn)
        case kIconColumnIdentifier:
            let iconView = view as? IconTableCellView
            let iconType = { () -> IconType in
                if chat.isSystemComment { return .none }
                let iconUrl = nicoManager.userIconUrl(for: chat.userId)
                return .user(iconUrl)
            }()
            iconView?.configure(iconType: iconType)
        case kCommentColumnIdentifier:
            let commentView = view as? CommentTableCellView
            let (content, attributes) = contentAndAttributes(forMessage: message)
            let attributed = NSAttributedString(string: content as String, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
            commentView?.attributedString = attributed
        case kUserIdColumnIdentifier:
            guard let live = live else { return }
            let userIdView = view as? UserIdTableCellView
            let handleName = HandleNameManager.shared.handleName(forLive: live, chat: chat)
            userIdView?.info = (
                nicoManager: nicoManager,
                handleName: handleName,
                userId: chat.userId,
                premium: chat.premium,
                comment: chat.comment)
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
        logSystemMessageToTable(L10n.loginCompleted)
    }
}

// MARK: - NicoManagerDelegate Functions
extension MainViewController: NicoManagerDelegate {
    func nicoManagerNeedsToken(_ nicoManager: NicoManagerType) {
        showAuthWindowController()
    }

    func nicoManagerDidConfirmTokenExistence(_ nicoManager: NicoManagerType) {
        // nop
    }

    func nicoManagerWillPrepareLive(_ nicoManager: NicoManagerType) {
        updateMainControlViews(status: .connecting)
    }

    func nicoManagerDidPrepareLive(_ nicoManager: NicoManagerType, user: User, live: Live, connectContext: NicoConnectContext) {
        self.live = live

        delegate?.mainViewControllerDidPrepareLive(
            self,
            title: live.title,
            community: live.community?.title ?? "-")

        updateCommunityViews(for: live)

        if live.isTimeShift {
            resetElapsedLabel()
            resetActiveUser()
            updateRankingLabel(rank: nil, date: nil)
            logSystemMessageToTable(L10n.preparedLive(user.nickname))
            return
        }

        focusCommentTextField()
        startElapsedTimeAndActiveUserTimer()

        switch connectContext {
        case .normal:
            resetActiveUser()
            rankingManager.addDelegate(self, for: live.liveId)
            logSystemMessageToTable(L10n.preparedLive(user.nickname))
        case .reconnect:
            break
        }

        logDebugRankingManagerStatus()
    }

    func nicoManagerDidFailToPrepareLive(_ nicoManager: NicoManagerType, error: NicoError) {
        logSystemMessageToTable(L10n.failedToPrepareLive(error.toMessage))
        updateMainControlViews(status: .disconnected)
        rankingManager.removeDelegate(self)
        logDebugRankingManagerStatus()
    }

    func nicoManagerDidConnectToLive(_ nicoManager: NicoManagerType, roomPosition: RoomPosition, connectContext: NicoConnectContext) {
        guard connectedToLive == false else { return }
        connectedToLive = true
        switch connectContext {
        case .normal:
            liveStartedDate = Date()
            logSystemMessageToTable(L10n.connectedToLive)
        case .reconnect(let reason):
            switch reason {
            case .normal:
                logSystemMessageToTable(L10n.reconnected)
            case .noPong, .noTexts:
                break
            }
        }
        updateMainControlViews(status: .connected)
        updateSpeechManagerState()
    }

    func nicoManagerDidReceiveChat(_ nicoManager: NicoManagerType, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")
        guard let live = live else { return }
        HandleNameManager.shared.extractAndUpdateHandleName(live: live, chat: chat)
        appendToTable(chat: chat)

        for userWindowController in userWindowControllers where chat.userId == userWindowController.userId {
            DispatchQueue.main.async {
                userWindowController.reloadMessages()
            }
        }
    }

    func nicoManagerWillReconnectToLive(_ nicoManager: NicoManagerType, reason: NicoReconnectReason) {
        switch reason {
        case .normal:
            // logSystemMessageToTableView(L10n.reconnecting)
            break
        case .noPong, .noTexts:
            break
        }
        logDebugReconnectReason(reason)
    }

    func nicoManagerReceivingTimeShiftChats(_ nicoManager: NicoManagerType, requestCount: Int, totalChatCount: Int) {
        let shouldLog = requestCount % 5 == 0
        guard shouldLog else { return }
        logSystemMessageToTable(L10n.receivingComments(totalChatCount))
    }

    func nicoManagerDidReceiveTimeShiftChats(_ nicoManager: NicoManagerType, chats: [Chat]) {
        logSystemMessageToTable(L10n.receivedComments(chats.count))
        guard let live = live else { return }
        chats.forEach {
            HandleNameManager.shared.extractAndUpdateHandleName(live: live, chat: $0)
        }
        bulkAppendToTable(chats: chats)
    }

    func nicoManagerDidDisconnect(_ nicoManager: NicoManagerType, disconnectContext: NicoDisconnectContext) {
        switch disconnectContext {
        case .normal:
            logSystemMessageToTable(L10n.liveClosed)
        case .reconnect(let reason):
            switch reason {
            case .normal:
                logSystemMessageToTable(L10n.liveClosed)
            case .noPong, .noTexts:
                break
            }
        }
        stopElapsedTimeAndActiveUserTimer()
        connectedToLive = false
        updateSpeechManagerState()

        switch disconnectContext {
        case .normal:
            updateMainControlViews(status: .disconnected)
            rankingManager.removeDelegate(self)
        case .reconnect:
            updateMainControlViews(status: .connecting)
        }

        logDebugRankingManagerStatus()
    }

    func nicoManagerDidReceiveStatistics(_ nicoManager: NicoManagerType, stat: LiveStatistics) {
        updateLiveStatistics(stat: stat)
    }
}

extension MainViewController: RankingManagerDelegate {
    func rankingManager(_ rankingManager: RankingManagerType, didUpdateRank rank: Int?, for liveId: String, at date: Date?) {
        updateRankingLabel(rank: rank, date: date)
    }

    func rankingManager(_ rankingManager: RankingManagerType, hasDebugMessage message: String) {
        guard logDebugInfo else { return }
        logSystemMessageToTable(message)
    }
}

// MARK: - UserWindowControllerDelegate Functions
extension MainViewController: UserWindowControllerDelegate {
    func userWindowControllerWillClose(_ userWindowController: UserWindowController) {
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
            nicoManager.disconnect()
        }
        nicoManager.logout()
        authWindowController.logout()
        logSystemMessageToTable(L10n.logoutCompleted)
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
        } else if let userName = nicoManager.cachedUserName(forChat: chat) {
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

    func toggleSpeech() {
        speakButton.state = speakButton.isOn ? .off : .on   // set "toggled" state
        speakButtonStateChanged(self)
    }

    func toggleCommentAnonymouslyButtonState() {
        commentAnonymouslyButton.state = commentAnonymouslyButton.isOn ? .off : .on  // set "toggled" state
        commentAnonymouslyButtonStateChanged(self)
    }

    func disconnect() {
        guard connectedToLive else { return }
        nicoManager.disconnect()
    }

    var clickedMessage: Message? {
        guard tableView.clickedRow != -1 else { return nil }
        return messageContainer[tableView.clickedRow]
    }

    func userPageUrl(for userId: String) -> URL? {
        return nicoManager.userPageUrl(for: userId)
    }

    func setVoiceVolume(_ volume: Int) {
        speechManager.setVoiceVolume(volume)
    }
}

// MARK: Utility
extension MainViewController {
    func changeEnableCommentSpeech(_ enabled: Bool) {
        // log.debug("\(enabled)")
        updateSpeechManagerState()
    }

    func changeFontSize(_ fontSize: Float) {
        tableViewFontSize = CGFloat(fontSize)

        minimumRowHeight = calculateMinimumRowHeight(fontSize: tableViewFontSize)
        tableView.rowHeight = minimumRowHeight
        rowHeightCache.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }

    func changeEnableMuteUserIds(_ enabled: Bool) {
        messageContainer.enableMuteUserIds = enabled
        log.debug("Changed enable mute user ids: \(enabled)")
        rebuildFilteredMessages()
    }

    func changeMuteUserIds(_ muteUserIds: [[String: String]]) {
        messageContainer.muteUserIds = muteUserIds
        log.debug("Changed mute user ids: \(muteUserIds)")
        rebuildFilteredMessages()
    }

    func changeEnableMuteWords(_ enabled: Bool) {
        messageContainer.enableMuteWords = enabled
        log.debug("Changed enable mute words: \(enabled)")
        rebuildFilteredMessages()
    }

    func changeMuteWords(_ muteWords: [[String: String]]) {
        messageContainer.muteWords = muteWords
        log.debug("Changed mute words: \(muteWords)")
        rebuildFilteredMessages()
    }

    func changeLogDebugInfo(_ enabled: Bool) {
        let changed = logDebugInfo != enabled
        guard changed else { return }
        logDebugInfo = enabled
        logSystemMessageToTable("Debug log \(logDebugInfo ? "enabled" : "disabled").")
    }

    private func rebuildFilteredMessages() {
        DispatchQueue.main.async {
            self.progressIndicator.startAnimation(self)
            let shouldScroll = self.scrollView.isReachedToBottom
            self.messageContainer.rebuildFilteredMessages {
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

// MARK: Chat Message Utility
private extension MainViewController {
    func logSystemMessageToTable(_ message: String) {
        appendToTable(systemMessage: message)
    }
}

// MARK: Configure Views
private extension MainViewController {
    func configureViews() {
        communityImageView.addBorder()
        [debugReconnectButton, debugExpireTokenButton].forEach {
            $0?.isHidden = !enableDebugButtons
        }

        liveUrlTextField.placeholderString = L10n.liveUrlTextFieldPlaceholder

        liveTitleLabel.stringValue = "[\(L10n.liveTitle)]"
        communityTitleLabel.stringValue = "[\(L10n.communityName)]"

        visitorsIconImageView.toolTip = L10n.visitorCount
        visitorsValueLabel.toolTip = L10n.visitorCount
        visitorsValueLabel.stringValue = defaultLabelValue
        commentsIconImageView.toolTip = L10n.commentCount
        commentsValueLabel.toolTip = L10n.commentCount
        commentsValueLabel.stringValue = defaultLabelValue
        adPointsIconImageView.toolTip = L10n.adPoints
        adPointsValueLabel.toolTip = L10n.adPoints
        adPointsValueLabel.stringValue = defaultLabelValue
        giftPointsIconImageView.toolTip = L10n.giftPoints
        giftPointsLabel.toolTip = L10n.giftPoints
        giftPointsLabel.stringValue = defaultLabelValue

        speakButton.title = L10n.speakComment

        if #available(macOS 10.14, *) {
            speakButton.isHidden = false
        } else {
            speakButton.isHidden = true
        }

        commentTextField.placeholderString = L10n.commentTextFieldPlaceholder

        elapsedTimeValueLabel.stringValue = defaultElapsedTimeValue
        activeUserIconImageView.toolTip = L10n.activeUserDescription
        activeUserValueLabel.toolTip = L10n.activeUserDescription
        maxActiveUserValueLabel.toolTip = L10n.activeUserDescription
        activeUserChartView.toolTip = L10n.activeUserHistoryDescription
        rankingIconImageView.toolTip = L10n.rankingDescription
        rankingValueLabel.toolTip = L10n.rankingDescription
        rankingDateLabel.toolTip = L10n.rankingDescription
        updateRankingLabel(rank: nil, date: nil)

        scrollView.enableScrollButtons()
        configureTableView()
        registerNibs()

        configureActiveUserChart()
        resetActiveUser()
    }

    func configureTableView() {
        tableView.setClickAction(
            clickHandler: nil,
            doubleClickHandler: { [weak self] in self?.openUserWindow() }
        )
    }

    func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameTimeTableCellView, kTimeColumnIdentifier),
            (kNibNameIconTableCellView, kIconColumnIdentifier),
            (kNibNameCommentTableCellView, kCommentColumnIdentifier),
            (kNibNameUserIdTableCellView, kUserIdColumnIdentifier),
            (kNibNamePremiumTableCellView, kPremiumColumnIdentifier)]

        for (nibName, identifier) in nibs {
            guard let nib = NSNib(nibNamed: nibName, bundle: Bundle.main) else { continue }
            tableView.register(nib, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier))
        }
    }

    func configureManagers() {
        nicoManager.delegate = self
    }

    func configureMute() {
        let enableMuteUserIds = UserDefaults.standard.bool(forKey: Parameters.enableMuteUserIds)
        let muteUserIds = UserDefaults.standard.array(forKey: Parameters.muteUserIds) as? [[String: String]]
        let enableMuteWords = UserDefaults.standard.bool(forKey: Parameters.enableMuteWords)
        let muteWords = UserDefaults.standard.array(forKey: Parameters.muteWords) as? [[String: String]]

        changeEnableMuteUserIds(enableMuteUserIds)
        if let muteUserIds = muteUserIds { changeMuteUserIds(muteUserIds) }
        changeEnableMuteWords(enableMuteWords)
        if let muteWords = muteWords { changeMuteWords(muteWords) }
    }

    func configureFontSize() {
        let fontSize = UserDefaults.standard.float(forKey: Parameters.fontSize)
        changeFontSize(fontSize)
    }

    func configureAnonymouslyButton() {
        let anonymous = UserDefaults.standard.bool(forKey: Parameters.commentAnonymously)
        commentAnonymouslyButton.state = anonymous ? .on : .off
    }

    func configureDebugLogInfo() {
        let enabled = UserDefaults.standard.bool(forKey: Parameters.logDebugInfo)
        changeLogDebugInfo(enabled)
    }

    func updateMainControlViews(status connectionStatus: ConnectionStatus) {
        DispatchQueue.main.async { self._updateMainControlViews(status: connectionStatus) }
    }

    func _updateMainControlViews(status connectionStatus: ConnectionStatus) {
        let controls: [NSControl] = [grabUrlButton, liveUrlTextField, connectButton]
        switch connectionStatus {
        case .disconnected:
            controls.forEach { $0.isEnabled = true }
            connectButton.image = Asset.playArrowBlack.image
            progressIndicator.stopAnimation(self)
        case .connecting:
            controls.forEach { $0.isEnabled = false }
            progressIndicator.startAnimation(self)
        case .connected:
            controls.forEach { $0.isEnabled = true }
            connectButton.image = Asset.stopBlack.image
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
        communityTitleLabel.stringValue = live.community?.title ?? "-"
    }
}

// MARK: Chat Message Utility (Private)
private extension MainViewController {
    func appendToTable(chat: Chat) {
        DispatchQueue.main.async {
            let result = self.messageContainer.append(chat: chat)
            self._updateTable(appended: result.appended, messageCount: result.count)
        }
    }

    func appendToTable(systemMessage: String) {
        DispatchQueue.main.async {
            let result = self.messageContainer.append(systemMessage: systemMessage)
            self._updateTable(appended: result.appended, messageCount: result.count)
        }
    }

    func _updateTable(appended: Bool, messageCount: Int) {
        guard appended else { return }
        let shouldScroll = scrollView.isReachedToBottom
        let rowIndex = messageCount - 1
        let message = messageContainer[rowIndex]
        tableView.insertRows(at: IndexSet(integer: rowIndex), withAnimation: NSTableView.AnimationOptions())
        if shouldScroll {
            scrollView.scrollToBottom()
        }
        if message.messageType == .chat, let chat = message.chat {
            handleSpeech(chat: chat)
        }
        scrollView.flashScrollers()
    }

    func bulkAppendToTable(chats: [Chat]) {
        DispatchQueue.main.async {
            chats.forEach {
                self.messageContainer.append(chat: $0)
            }
            self.tableView.reloadData()
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
        let adPoints = String(stat.adPoints ?? 0).numberStringWithSeparatorComma()
        let giftPoints = String(stat.giftPoints ?? 0).numberStringWithSeparatorComma()
        DispatchQueue.main.async {
            self.visitorsValueLabel.stringValue = visitors
            self.commentsValueLabel.stringValue = comments
            self.adPointsValueLabel.stringValue = adPoints
            self.giftPointsLabel.stringValue = giftPoints
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
        let reason: NicoReconnectReason
        reason = .normal
        // reason = .noPong
        // reason = .noTexts
        nicoManager.reconnect(reason: reason)
    }

    @IBAction func debugExpireTokenButtonPressed(_ sender: Any) {
        nicoManager.injectExpiredAccessToken()
        logSystemMessageToTable("Injected expired access token.")
    }

    @IBAction func connectLive(_ sender: AnyObject) {
        initializeHandleNameManager()
        guard let liveProgramId = liveUrlTextField.stringValue.extractLiveProgramId() else { return }

        clearAllChats()
        communityImageView.image = Asset.defaultCommunityImage.image

        nicoManager.connect(liveProgramId: liveProgramId)
    }

    @IBAction func connectButtonPressed(_ sender: AnyObject) {
        if connectedToLive {
            nicoManager.disconnect()
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

        nicoManager.comment(comment, anonymously: commentAnonymouslyButton.isOn) { comment in
            if comment == nil {
                self.logSystemMessageToTable(L10n.failedToComment)
            }
        }
        commentTextField.stringValue = ""

        if commentHistory.count == 0 || commentHistory.last != comment {
            commentHistory.append(comment)
            commentHistoryIndex = commentHistory.count
        }
    }

    @IBAction func speakButtonStateChanged(_ sender: Any) {
        updateSpeechManagerState()
    }

    @IBAction func commentAnonymouslyButtonStateChanged(_ sender: Any) {
        let isOn = commentAnonymouslyButton.state == .on
        UserDefaults.standard.setValue(isOn, forKey: Parameters.commentAnonymously)
    }
}

// MARK: User Window Functions
private extension MainViewController {
    func openUserWindow() {
        let clickedRow = tableView.clickedRow
        guard clickedRow != -1 else { return }

        let message = messageContainer[clickedRow]
        guard message.messageType == .chat, let chat = message.chat else { return }
        var userWindowController: UserWindowController?

        // check if user window exists?
        for existing in userWindowControllers where chat.userId == existing.userId {
            userWindowController = existing
            log.debug("existing user-wc found, use it:\(userWindowController?.description ?? "")")
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
                delegate: self,
                nicoManager: nicoManager,
                messageContainer: messageContainer,
                userId: chat.userId,
                handleName: handleName)
            if let uwc = userWindowController {
                positionUserWindow(uwc.window)
                log.debug("no existing user-wc found, create it:\(uwc.description)")
                userWindowControllers.append(uwc)
            }
        }
        userWindowController?.showWindow(self)
    }

    func positionUserWindow(_ userWindow: NSWindow?) {
        guard let userWindow = userWindow else { return }
        var topLeftPoint: NSPoint = nextUserWindowTopLeftPoint
        if userWindowControllers.count == 0 {
            topLeftPoint = userWindowDefaultTopLeftPoint
        }
        nextUserWindowTopLeftPoint = userWindow.cascadeTopLeft(from: topLeftPoint)
    }
}

// MARK: Timer Functions
private extension MainViewController {
    func startElapsedTimeAndActiveUserTimer() {
        elapsedTimeTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(MainViewController.updateElapsedLabelValue),
            userInfo: nil,
            repeats: true)
        activeUserTimer = Timer.scheduledTimer(
            timeInterval: calculateActiveUserInterval,
            target: self,
            selector: #selector(MainViewController.calculateAndUpdateActiveUser),
            userInfo: nil,
            repeats: true)
    }

    func stopElapsedTimeAndActiveUserTimer() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
        activeUserTimer?.invalidate()
        activeUserTimer = nil
    }

    @objc func updateElapsedLabelValue() {
        var display = defaultElapsedTimeValue

        if let beginTime = nicoManager.live?.beginTime {
            var prefix = ""
            var elapsed = Date().timeIntervalSince(beginTime as Date)
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

    func resetElapsedLabel() {
        DispatchQueue.main.async {
            self.elapsedTimeValueLabel.stringValue = defaultElapsedTimeValue
        }
    }

    @objc func calculateAndUpdateActiveUser() {
        messageContainer.calculateActive { (active: Int?) -> Void in
            guard let active = active else { return }
            self.updateActiveUser(active: active)
            DispatchQueue.main.async {
                self.updateActiveUserLabels()
                self.updateActiveUserChart()
            }
        }
    }
}

// MARK: Active User
private extension MainViewController {
    func updateActiveUser(active: Int) {
        activeUserCount = active
        maxActiveUserCount = max(maxActiveUserCount, active)
        if activeUserHistory.isEmpty {
            let originDate = Date().addingTimeInterval(chartDuration * -1)
            for i in 0...Int(chartDuration / calculateActiveUserInterval) {
                let date = originDate.addingTimeInterval(calculateActiveUserInterval * Double(i))
                activeUserHistory.append((date, 0))
            }
        }
        activeUserHistory.append((Date(), active))
        activeUserHistory = activeUserHistory.filter { Date().timeIntervalSince($0.0) < chartDuration }
    }

    func resetActiveUser() {
        activeUserCount = 0
        maxActiveUserCount = 0
        activeUserHistory.removeAll()
        updateActiveUserLabels()
        updateActiveUserChart()
    }

    func updateActiveUserLabels() {
        if activeUserHistory.isEmpty {
            activeUserValueLabel.stringValue = defaultLabelValue
            maxActiveUserValueLabel.stringValue = defaultLabelValue
            return
        }
        activeUserValueLabel.stringValue = String(activeUserCount)
        maxActiveUserValueLabel.stringValue = String(maxActiveUserCount)
    }
}

// MARK: Speech Handlers
private extension MainViewController {
    func updateSpeechManagerState() {
        guard #available(macOS 10.14, *) else { return }
        if speakButton.isOn && connectedToLive && live?.isTimeShift == false {
            speechManager.startManager()
        } else {
            speechManager.stopManager()
        }
    }

    func handleSpeech(chat: Chat) {
        guard #available(macOS 10.14, *) else { return }
        guard speakButton.isOn else { return }
        guard live?.isTimeShift == false else {
            // log.debug("Skip enqueing since speech for time shift program is not supported.")
            return
        }
        guard let started = liveStartedDate,
              Date().timeIntervalSince(started) > 5 else {
            // Skip enqueuing since there's possibility that we receive lots of
            // messages for this time slot.
            log.debug("Skip enqueuing early chats.")
            return
        }
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            self.speechManager.enqueue(chat: chat)
            if self.speechManager.refreshChatQueueIfQueuedTooMuch() {
                // logSystemMessageToTableView("Refreshed speech queue.")
            }
        }
    }
}

// MARK: Chart Functions
private extension MainViewController {
    var chartDuration: TimeInterval { 20 * 60 } // 20 min

    func configureActiveUserChart() {
        // https://stackoverflow.com/a/41241795/13220031
        activeUserChartView.minOffset = 0
        activeUserChartView.noDataText = defaultChartText
        activeUserChartView.toolTip = L10n.activeUserHistoryDescription

        activeUserChartView.leftAxis.drawAxisLineEnabled = false
        activeUserChartView.leftAxis.drawLabelsEnabled = false

        activeUserChartView.rightAxis.enabled = false

        activeUserChartView.xAxis.drawLabelsEnabled = false
        activeUserChartView.xAxis.drawGridLinesEnabled = false

        activeUserChartView.legend.enabled = false
    }

    func updateActiveUserChart() {
        guard !activeUserHistory.isEmpty else {
            activeUserChartView.clear()
            return
        }

        let entries = activeUserHistory
            .map { ($0.0.timeIntervalSince1970, Double($0.1))}
            .map { ChartDataEntry(x: $0.0, y: $0.1) }
        let data = LineChartData()
        let ds = LineChartDataSet(entries: entries, label: "")
        ds.colors = [NSColor.controlTextColor]
        ds.drawCirclesEnabled = false
        ds.drawValuesEnabled = false
        ds.highlightEnabled = false
        data.append(ds)
        adjustChartLeftAxis(max: maxActiveUserCount)
        activeUserChartView.data = data
    }

    func adjustChartLeftAxis(max: Int) {
        let _max = max == 0 ? 10 : max  // `10` is temporary axis max value for no data case
        let padding = Double(_max) * 0.05
        activeUserChartView.leftAxis.axisMinimum = -1 * padding
        activeUserChartView.leftAxis.axisMaximum = Double(_max) + padding
    }
}

// MARK: Ranking Methods
private extension MainViewController {
    func updateRankingLabel(rank: Int?, date: Date?) {
        let _rank: String = {
            guard let rank = rank else { return defaultLabelValue }
            return "#\(rank)"
        }()
        let _date: String = {
            guard let date = date else { return "[\(defaultRankDateText)]" }
            let formatter = DateFormatter()
            formatter.dateFormat = "H:mm"
            return "[\(formatter.string(from: date))]"
        }()
        DispatchQueue.main.async {
            self.rankingValueLabel.stringValue = _rank
            self.rankingDateLabel.stringValue = _date
        }
    }
}

// MARK: Misc Utility
private extension MainViewController {
    func clearAllChats() {
        messageContainer.removeAll()
        rowHeightCache.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }

    func showAuthWindowController() {
        authWindowController.startAuthorization()
        authWindowController.showWindow(self)
    }
}

// MARK: Debug Methods
private extension MainViewController {
    func logDebugMessageIfEnabled(_ message: String) {
        guard logDebugInfo else { return }
        logSystemMessageToTable(message)
    }

    func logDebugReconnectReason(_ reason: NicoReconnectReason) {
        let _reason: String = {
            switch reason {
            case .normal:   return "normal"
            case .noPong:   return "no pong"
            case .noTexts:  return "no text"
            }
        }()
        logDebugMessageIfEnabled("Reconnecting... (\(_reason))")
    }

    func logDebugRankingManagerStatus() {
        logDebugMessageIfEnabled("RankingManager is \(rankingManager.isRunning ? "running" : "stopped").")
    }
}

private extension NicoError {
    var toMessage: String {
        switch self {
        case .internal:                 return L10n.errorInternal
        case .noLiveInfo:               return L10n.errorNoLiveInfo
        case .noMessageServerInfo:      return L10n.errorNoMessageServerInfo
        case .openMessageServerFailed:  return L10n.errorFailedToOpenMessageServer
        }
    }
}

private extension NSButton {
    var isOn: Bool { self.state == .on }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// swiftlint:enable file_length
