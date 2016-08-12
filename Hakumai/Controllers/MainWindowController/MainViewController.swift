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

private let kCommunityImageDefaultName = "NoImage"
private let kUserWindowDefautlTopLeftPoint = NSMakePoint(100, 100)
private let kDelayToShowHbIfseetnoCommands: TimeInterval = 30
private let kCalculateActiveInterval: TimeInterval = 5
private let kMaximumFontSizeForNonMainColumn: CGFloat = 16
private let kDefaultMinimumRowHeight: CGFloat = 17

class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate, NicoUtilityDelegate, UserWindowControllerDelegate {
    // MARK: - Properties
    static var sharedInstance: MainViewController!

    // MARK: Main Outlets
    @IBOutlet weak var liveTextField: NSTextField!
    
    @IBOutlet weak var communityImageView: NSImageView!
    @IBOutlet weak var liveTitleLabel: NSTextField!
    @IBOutlet weak var communityTitleLabel: NSTextField!
    @IBOutlet weak var roomPositionLabel: NSTextField!
    
    @IBOutlet weak var visitorsLabel: NSTextField!
    @IBOutlet weak var commentsLabel: NSTextField!
    @IBOutlet weak var remainingSeatsLabel: NSTextField!
    
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var commentTextField: NSTextField!
    @IBOutlet weak var commentAnonymouslyButton: NSButton!
    @IBOutlet weak var elapsedLabel: NSTextField!
    @IBOutlet weak var activeLabel: NSTextField!
    @IBOutlet weak var notificationLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    // MARK: Menu Delegate
    @IBOutlet var menuDelegate: MenuDelegate!
    
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
    private var commentHistoryIndex: Int?
    
    private var elapsedTimer: Timer?
    private var activeTimer: Timer?

    private var userWindowControllers = [UserWindowController]()
    private var nextUserWindowTopLeftPoint: NSPoint = NSZeroPoint
    
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        MainViewController.sharedInstance = self
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
    
    override var representedObject: AnyObject? {
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
            let nib = NSNib(nibNamed: nibName, bundle: Bundle.main)
            tableView.register(nib!, forIdentifier: identifier)
        }
    }
    
    // MARK: Utility
    func changeShowHbIfseetnoCommands(_ show: Bool) {
        MessageContainer.sharedContainer.showHbIfseetnoCommands = show
        logger.debug("changed show 'hbifseetno' commands: \(show)")
        
        rebuildFilteredMessages()
    }
    
    func changeEnableCommentSpeech(_ enabled: Bool) {
        // logger.debug("\(enabled)")
        updateSpeechManagerState()
    }
    
    func changeFontSize(_ fontSize: CGFloat) {
        tableViewFontSize = fontSize
        
        minimumRowHeight = calculateMinimumRowHeightWithFontSize(tableViewFontSize)
        tableView.rowHeight = minimumRowHeight
        rowHeightCacher.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }
    
    func changeEnableMuteUserIds(_ enabled: Bool) {
        MessageContainer.sharedContainer.enableMuteUserIds = enabled
        logger.debug("changed enable mute userids: \(enabled)")
        
        rebuildFilteredMessages()
    }
    
    func changeMuteUserIds(_ muteUserIds: [[String: String]]) {
        MessageContainer.sharedContainer.muteUserIds = muteUserIds
        logger.debug("changed mute userids: \(muteUserIds)")
        
        rebuildFilteredMessages()
    }
    
    func changeEnableMuteWords(_ enabled: Bool) {
        MessageContainer.sharedContainer.enableMuteWords = enabled
        logger.debug("changed enable mute words: \(enabled)")
        
        rebuildFilteredMessages()
    }
    
    func changeMuteWords(_ muteWords: [[String: String]]) {
        MessageContainer.sharedContainer.muteWords = muteWords
        logger.debug("changed mute words: \(muteWords)")
        
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

        let commentTableColumn = tableView.tableColumn(withIdentifier: kCommentColumnIdentifier)!
        let commentColumnWidth = commentTableColumn.width
        rowHeight = commentColumnHeight(message, width: commentColumnWidth)
        
        rowHeightCacher[message.messageNo] = rowHeight
        
        return rowHeight
    }
    
    private func commentColumnHeight(_ message: Message, width: CGFloat) -> CGFloat {
        let leadingSpace: CGFloat = 2
        let trailingSpace: CGFloat = 2
        let widthPadding = leadingSpace + trailingSpace

        let (content, attributes) = contentAndAttributesForMessage(message)
        
        let commentRect = content.boundingRect(
            with: CGSize(width: width - widthPadding, height: 0), options: NSStringDrawingOptions.usesLineFragmentOrigin,
            attributes: attributes)
        // logger.debug("\(commentRect.size.width),\(commentRect.size.height)")
        
        return max(commentRect.size.height, minimumRowHeight)
    }
    
    private func calculateMinimumRowHeightWithFontSize(_ fontSize: CGFloat) -> CGFloat {
        let placeholderContent = "." as NSString
        let placeholderAttributes = UIHelper.normalCommentAttributesWithFontSize(fontSize)
        let rect = placeholderContent.boundingRect(
            with: CGSize(width: 1, height: 0), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: placeholderAttributes)
        return rect.size.height
    }
    
    func tableViewColumnDidResize(_ aNotification: Notification) {
        let column = (aNotification as NSNotification).userInfo?["NSTableColumn"] as! NSTableColumn
        
        if column.identifier == kCommentColumnIdentifier {
            rowHeightCacher.removeAll(keepingCapacity: false)
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var view: NSTableCellView?
        
        if let identifier = tableColumn?.identifier {
            view = tableView.make(withIdentifier: identifier, owner: self) as? NSTableCellView
            view?.textField?.stringValue = ""
        }

        let message = MessageContainer.sharedContainer[row]
        
        if message.messageType == .system {
            configureViewForSystemMessage(message, tableColumn: tableColumn!, view: view!)
        }
        else if message.messageType == .chat {
            configureViewForChat(message, tableColumn: tableColumn!, view: view!)
        }
        
        return view
    }
    
    private func configureViewForSystemMessage(_ message: Message, tableColumn: NSTableColumn, view: NSTableCellView) {
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = (view as! RoomPositionTableCellView)
            roomPositionView.roomPosition = nil
            roomPositionView.commentNo = nil
            roomPositionView.fontSize = nil
        case kScoreColumnIdentifier:
            let scoreView = view as! ScoreTableCellView
            scoreView.chat = nil
            scoreView.fontSize = nil
        case kCommentColumnIdentifier:
            let (content, attributes) = contentAndAttributesForMessage(message)
            let attributed = NSAttributedString(string: content as String, attributes: attributes)
            view.textField?.attributedStringValue = attributed
        case kUserIdColumnIdentifier:
            let userIdView = view as! UserIdTableCellView
            userIdView.info = nil
            userIdView.fontSize = nil
        case kPremiumColumnIdentifier:
            let premiumView = view as! PremiumTableCellView
            premiumView.premium = nil
            premiumView.fontSize = nil
        default:
            break
        }
    }

    private func configureViewForChat(_ message: Message, tableColumn: NSTableColumn, view: NSTableCellView) {
        let chat = message.chat!
        
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = view as! RoomPositionTableCellView
            roomPositionView.roomPosition = chat.roomPosition!
            roomPositionView.commentNo = chat.no!
            roomPositionView.fontSize = min(tableViewFontSize, kMaximumFontSizeForNonMainColumn)
        case kScoreColumnIdentifier:
            let scoreView = view as! ScoreTableCellView
            scoreView.chat = chat
            scoreView.fontSize = min(tableViewFontSize, kMaximumFontSizeForNonMainColumn)
        case kCommentColumnIdentifier:
            let (content, attributes) = contentAndAttributesForMessage(message)
            let attributed = NSAttributedString(string: content as String, attributes: attributes)
            view.textField?.attributedStringValue = attributed
        case kUserIdColumnIdentifier:
            let userIdView = view as! UserIdTableCellView
            let handleName = HandleNameManager.sharedManager.handleNameForLive(live!, chat: chat)
            userIdView.info = (handleName: handleName, userId: chat.userId, premium: chat.premium, comment: chat.comment)
            userIdView.fontSize = tableViewFontSize
        case kPremiumColumnIdentifier:
            let premiumView = view as! PremiumTableCellView
            premiumView.premium = chat.premium
            premiumView.fontSize = min(tableViewFontSize, kMaximumFontSizeForNonMainColumn)
        default:
            break
        }
    }
    
    // MARK: Utility
    private func contentAndAttributesForMessage(_ message: Message) -> (NSString, [String: AnyObject]) {
        var content: NSString!
        var attributes: [String: AnyObject]!
        
        if message.messageType == .system {
            content = message.message!
            attributes = UIHelper.normalCommentAttributesWithFontSize(tableViewFontSize)
        }
        else if message.messageType == .chat {
            content = message.chat!.comment!
            if message.firstChat == true {
                attributes = UIHelper.boldCommentAttributesWithFontSize(tableViewFontSize)
            }
            else {
                attributes = UIHelper.normalCommentAttributesWithFontSize(tableViewFontSize)
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
            }
            else {
                handleCommentTextFieldKeyUpDown(isMovedUp: isMovedUp, isMovedDown: isMovedDown)
            }
            
            return true
        }
        
        return false
    }
    
    private func handleCommentTextFieldKeyUpDown(isMovedUp: Bool, isMovedDown: Bool) {
        if isMovedUp && 0 <= commentHistoryIndex {
            commentHistoryIndex! -= 1
        }
        else if isMovedDown && commentHistoryIndex <= (commentHistory.count - 1) {
            commentHistoryIndex! += 1
        }
        
        let inValidHistoryRange = (0 <= commentHistoryIndex && commentHistoryIndex <= (commentHistory.count - 1))
        
        commentTextField.stringValue = (inValidHistoryRange ? commentHistory[commentHistoryIndex!] : "")
        
        // selectText() should be called in next run loop, http://stackoverflow.com/a/2196751
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.commentTextField.selectText(self)
        }
    }
    
    // MARK: - NicoUtilityDelegate Functions
    func nicoUtilityWillPrepareLive(_ nicoUtility: NicoUtility) {
        DispatchQueue.main.async {
            self.progressIndicator.startAnimation(self)
        }
    }

    func nicoUtilityDidPrepareLive(_ nicoUtility: NicoUtility, user: User, live: Live) {
        self.live = live
        
        if let startTime = live.startTime {
            let beginDate = Date(timeInterval: kDelayToShowHbIfseetnoCommands, since: startTime as Date)
            MessageContainer.sharedContainer.beginDateToShowHbIfseetnoCommands = beginDate
        }
        
        DispatchQueue.main.async {
            self.liveTitleLabel.stringValue = live.title!
            
            let communityTitle = live.community.title ?? "-"
            let level = live.community.level != nil ? String(live.community.level!) : "-"
            self.communityTitleLabel.stringValue = communityTitle + " (Lv." + level + ")"
            self.roomPositionLabel.stringValue = user.roomLabel! + " - " + String(user.seatNo!)

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
        
        logSystemMessageToTableView("Prepared live as user \(user.nickname!).")
    }
    
    func nicoUtilityDidFailToPrepareLive(_ nicoUtility: NicoUtility, reason: String) {
        logSystemMessageToTableView("Failed to prepare live.(\(reason))")
        DispatchQueue.main.async {
            self.progressIndicator.stopAnimation(self)
        }
    }

    func nicoUtilityDidConnectToLive(_ nicoUtility: NicoUtility, roomPosition: RoomPosition) {
        if connectedToLive == false {
            connectedToLive = true
            logSystemMessageToTableView("Connected to live.")
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(self)
            }
            updateSpeechManagerState()
        }
    }

    func nicoUtilityDidReceiveFirstChat(_ nicoUtility: NicoUtility, chat: Chat) {
        if chat.roomPosition == nil {
            return
        }

        logSystemMessageToTableView("Opened \(chat.roomPosition!.label()).")

        if openedRoomPosition == nil {
            // nop
        }
        else if chat.roomPosition!.rawValue <= openedRoomPosition?.rawValue {
            return
        }
        openedRoomPosition = chat.roomPosition
        
        DispatchQueue.main.async(execute: {
            self.notificationLabel.stringValue = "Opened: ~\(chat.roomPosition!.label())"
        })
    }

    func nicoUtilityDidReceiveChat(_ nicoUtility: NicoUtility, chat: Chat) {
        // logger.debug("\(chat.mail),\(chat.comment)")
        if let live = live {
            HandleNameManager.sharedManager.extractAndUpdateHandleNameWithLive(live, chat: chat)
        }
        appendTableView(chat)
        
        for userWindowController in userWindowControllers {
            if chat.userId == userWindowController.userId {
                DispatchQueue.main.async(execute: {
                    userWindowController.reloadMessages()
                })
            }
        }
    }
    
    func nicoUtilityDidGetKickedOut(_ nicoUtility: NicoUtility) {
        logSystemMessageToTableView("Got kicked out...")
    }
    
    func nicoUtilityWillReconnectToLive(_ nicoUtility: NicoUtility) {
        logSystemMessageToTableView("Reconnecting...")
    }
    
    func nicoUtilityDidDisconnect(_ nicoUtility: NicoUtility) {
        logSystemMessageToTableView("Live closed.")
        stopTimers()
        connectedToLive = false
        openedRoomPosition = nil
        updateSpeechManagerState()
    }
    
    func nicoUtilityDidReceiveHeartbeat(_ nicoUtility: NicoUtility, heartbeat: Heartbeat) {
        updateHeartbeatInformation(heartbeat)
    }
    
    // MARK: System Message Utility
    func logSystemMessageToTableView(_ message: String) {
        appendTableView(message)
    }
    
    // MARK: Chat Append Utility
    private func appendTableView(_ chatOrSystemMessage: AnyObject) {
        DispatchQueue.main.async {
            let shouldScroll = self.shouldTableViewScrollToBottom()
            
            let (appended, count) = MessageContainer.sharedContainer.append(chatOrSystemMessage: chatOrSystemMessage)
            
            if appended {
                let rowIndex = count - 1
                let message = MessageContainer.sharedContainer[rowIndex]

                self.tableView.insertRows(at: IndexSet(integer: rowIndex), withAnimation: NSTableViewAnimationOptions())
                // self.logChat(chatOrSystemMessage)
                
                if shouldScroll {
                    self.scrollTableViewToBottom()
                }
                
                if (message.messageType == .chat) {
                    self.handleSpeechWithChat(message.chat!)
                }
                
                self.scrollView.flashScrollers()
            }
        }
    }
    
    private func logMessage(_ message: Message) {
        var content: String?
        
        if message.messageType == .system {
            content = message.message
        }
        else if message.messageType == .chat {
            content = message.chat!.comment
        }
        
        logger.debug("[ \(content!) ]")
    }
    
    private func shouldTableViewScrollToBottom() -> Bool {
        if 0 < currentScrollAnimationCount {
            return lastShouldScrollToBottom
        }
        
        let viewRect = scrollView.contentView.documentRect
        let visibleRect = scrollView.contentView.documentVisibleRect
        // logger.debug("\(viewRect)-\(visibleRect)")
        
        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10

        let shouldScroll = (bottomY <= (offsetBottomY + allowance))
        lastShouldScrollToBottom = shouldScroll
        
        return shouldScroll
    }
    
    private func scrollTableViewToBottom(_ animated: Bool = false) {
        let clipView = scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        let origin = NSMakePoint(x, y)
        
        if !animated {
            // note: do not use scrollRowToVisible here.
            // scroll will be sometimes stopped when very long comment arrives.
            // tableView.scrollRowToVisible(tableView.numberOfRows - 1)
            clipView.setBoundsOrigin(origin)
        }
        else {
            // http://stackoverflow.com/questions/19399242/soft-scroll-animation-nsscrollview-scrolltopoint
            currentScrollAnimationCount += 1
            // logger.debug("start scroll animation:\(currentScrollAnimationCount)")
            
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current().duration = 0.5
            
            NSAnimationContext.current().completionHandler = { () -> Void in
                self.currentScrollAnimationCount -= 1
                // logger.debug("  end scroll animation:\(self.currentScrollAnimationCount)")
            }
            
            clipView.animator().setBoundsOrigin(origin)
            // scrollView.reflectScrolledClipView(clipView)
            
            NSAnimationContext.endGrouping()
        }
    }
    
    // MARK: - UserWindowControllerDelegate Functions
    func userWindowControllerDidClose(_ userWindowController: UserWindowController) {
        logger.debug("")
        
        if let index = userWindowControllers.index(of: userWindowController) {
            userWindowControllers.remove(at: index)
        }
    }
    
    // MARK: - Public Functions
    func showHandleNameAddViewControllerWithLive(_ live: Live, chat: Chat) {
        let storyboard = NSStoryboard(name: kStoryboardNameMainWindowController, bundle: nil)
        let handleNameAddViewController = storyboard.instantiateController(withIdentifier: kStoryboardIdHandleNameAddViewController) as! HandleNameAddViewController
        
        handleNameAddViewController.handleName = (defaultHandleNameWithLive(live, chat: chat) ?? "")
        handleNameAddViewController.completion = { (cancelled: Bool, handleName: String?) -> Void in
            if !cancelled {
                HandleNameManager.sharedManager.updateHandleNameWithLive(live, chat: chat, handleName: handleName!)
                MainViewController.sharedInstance.refreshHandleName()
            }
            
            self.dismissViewController(handleNameAddViewController)
            // TODO: deinit in handleNameViewController is not called after this completion
        }
        
        presentViewControllerAsSheet(handleNameAddViewController)
    }
    
    private func defaultHandleNameWithLive(_ live: Live, chat: Chat) -> String? {
        var defaultHandleName: String?
        
        if let handleName = HandleNameManager.sharedManager.handleNameForLive(live, chat: chat) {
            defaultHandleName = handleName
        }
        else {
            if let userName = NicoUtility.sharedInstance.cachedUserNameForChat(chat) {
                defaultHandleName = userName
            }
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
        NicoUtility.sharedInstance.loadThumbnail { (imageData) -> (Void) in
            DispatchQueue.main.async {
                if imageData == nil {
                    return
                }
                self.communityImageView.image = NSImage(data: imageData! as Data)
            }
        }
    }
    
    private func updateHeartbeatInformation(_ heartbeat: Heartbeat) {
        if heartbeat.status != .ok {
            return
        }
        
        let visitors = String(heartbeat.watchCount!).numberStringWithSeparatorComma()!
        let comments = String(heartbeat.commentCount!).numberStringWithSeparatorComma()!
        
        var remaining = "-"
        if let free = heartbeat.freeSlotNum {
            remaining = free == 0 ? "満員" : String(free).numberStringWithSeparatorComma()!
        }
        
        DispatchQueue.main.async {
            self.visitorsLabel.stringValue = "Visitors: " + visitors
            self.commentsLabel.stringValue = "Comments: " + comments
            self.remainingSeatsLabel.stringValue = "Seats: " + remaining
        }
    }
    
    // MARK: Control Handlers
    @IBAction func grabUrlFromBrowser(_ sender: AnyObject) {
        if let url = BrowserHelper.urlFromBrowser(.chrome) {
            liveTextField.stringValue = url
            connectLive(self)
        }
    }
    
    @IBAction func connectLive(_ sender: AnyObject) {
        initializeHandleNameManager()
        
        if let liveNumber = MainViewController.extractLiveNumber(liveTextField.stringValue) {
            clearAllChats()

            communityImageView.image = NSImage(named: kCommunityImageDefaultName)

            NicoUtility.sharedInstance.delegate = self
            
            let defaults = UserDefaults.standard
            let sessionManagementType = SessionManagementType(rawValue: defaults.integer(forKey: Parameters.SessionManagement))!
            
            switch sessionManagementType {
            case .login:
                if let account = KeychainUtility.accountInKeychain() {
                    let mailAddress = account.mailAddress
                    let password = account.password
                    NicoUtility.sharedInstance.connectToLive(liveNumber, mailAddress: mailAddress, password: password)
                }
                
            case .chrome:
                NicoUtility.sharedInstance.connectToLive(liveNumber, browserType: .chrome)
            }
        }
    }
    
    @IBAction func comment(_ sender: AnyObject) {
        let comment = commentTextField.stringValue
        if comment.characters.count == 0 {
            return
        }
        
        let anonymously = UserDefaults.standard.bool(forKey: Parameters.CommentAnonymously)
        NicoUtility.sharedInstance.comment(comment, anonymously: anonymously) { comment in
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
    
    func openUserWindow(_ sender: AnyObject?) {
        let clickedRow = tableView.clickedRow
        
        if clickedRow == -1 {
            return
        }
        
        let message = MessageContainer.sharedContainer[clickedRow]
        
        if message.messageType != .chat || message.chat?.userId == nil {
            return
        }
        
        let chat = message.chat!

        var userWindowController: UserWindowController?
        
        // check if user window exists?
        for existing in userWindowControllers {
            if chat.userId == existing.userId {
                userWindowController = existing
                logger.debug("existing userwc found, use it:\(userWindowController)")
                break
            }
        }
        
        if userWindowController == nil {
            // not exist, so create and cache it
            userWindowController = UserWindowController.generateInstanceWithDelegate(self, userId: chat.userId!)
            positionUserWindow(userWindowController!.window!)
            logger.debug("no existing userwc found, create it:\(userWindowController)")
            userWindowControllers.append(userWindowController!)
        }
        
        userWindowController!.showWindow(self)
    }
    
    private func positionUserWindow(_ userWindow: NSWindow) {
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
    
    func displayElapsed(_ timer: Timer) {
        var display = "--:--:--"
        
        if let startTime = NicoUtility.sharedInstance.live?.startTime {
            var prefix = ""
            var elapsed = Date().timeIntervalSince(startTime as Date)
            
            if elapsed < 0 {
                prefix = "-"
                elapsed = abs(elapsed)
            }
            
            let hour = String(format:"%02d", Int(elapsed / 3600))
            let minute = String(format:"%02d", Int((elapsed / 60).truncatingRemainder(dividingBy: 60)))
            let second = String(format:"%02d", Int(elapsed.truncatingRemainder(dividingBy: 60)))
            
            display = "\(prefix)\(hour):\(minute):\(second)"
        }
        
        DispatchQueue.main.async {
            self.elapsedLabel.stringValue = "Elapsed: " + display
        }
    }
    
    func calculateActive(_ timer: Timer) {
        MessageContainer.sharedContainer.calculateActive { (active: Int?) -> (Void) in
            if active == nil {
                return
            }
            
            DispatchQueue.main.async {
                self.activeLabel.stringValue = "Active: \(active!)"
            }
        }
    }
    
    // MARK: Speech Handlers
    private func updateSpeechManagerState() {
        let enabled = UserDefaults.standard.bool(forKey: Parameters.EnableCommentSpeech)
        
        if enabled && connectedToLive {
            SpeechManager.sharedManager.startManager()
        }
        else {
            SpeechManager.sharedManager.stopManager()
        }
    }
    
    private func handleSpeechWithChat(_ chat: Chat) {
        let enabled = UserDefaults.standard.bool(forKey: Parameters.EnableCommentSpeech)
        
        guard enabled else {
            return
        }

        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            SpeechManager.sharedManager.enqueueChat(chat)
            
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
    
    class func extractLiveNumber(_ url: String) -> Int? {
        let liveNumberPattern = "\\d{9,}"
        var pattern: String

        pattern = "http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/lv(" + liveNumberPattern + ").*"

        if let extracted = url.extractRegexpPattern(pattern) {
            return Int(extracted)
        }

        pattern = "lv(" + liveNumberPattern + ")"

        if let extracted = url.extractRegexpPattern(pattern) {
            return Int(extracted)
        }

        pattern = "(" + liveNumberPattern + ")"

        if let extracted = url.extractRegexpPattern(pattern) {
            return Int(extracted)
        }

        return nil
    }
}
