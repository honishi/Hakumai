//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

private let kStoryboardNameMainWindowController = "MainWindowController"
private let kStoryboardIdHandleNameAddViewController = "HandleNameAddViewController"

private let kCommunityImageDefaultName = "NoImage"
private let kUserWindowDefautlTopLeftPoint = NSMakePoint(100, 100)
private let kDelayToShowHbIfseetnoCommands: NSTimeInterval = 30
private let kCalculateActiveInterval: NSTimeInterval = 5

class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate, NicoUtilityDelegate, UserWindowControllerDelegate {
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
    @IBOutlet weak var elapsedLabel: NSTextField!
    @IBOutlet weak var activeLabel: NSTextField!
    @IBOutlet weak var notificationLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    // MARK: Menu Delegate
    @IBOutlet var menuDelegate: MenuDelegate!
    
    // MARK: General Properties
    struct Static {
        static var instance: MainViewController!
    }
    
    class var sharedInstance : MainViewController {
        return Static.instance
    }

    let log = XCGLogger.defaultInstance()

    var connectedToLive = false
    var openedRoomPosition: RoomPosition?
    var chats = [Chat]()

    // row-height cache
    var rowHeightCacher = [Int: CGFloat]()
    var rowDefaultHeight: CGFloat!
    var lastShouldScrollToBottom = true
    var currentScrollAnimationCount = 0
    
    var commentHistory = [String]()
    var commentHistoryIndex: Int?
    
    var elapsedTimer: NSTimer?
    var activeTimer: NSTimer?

    var userWindowControllers = [UserWindowController]()
    var nextUserWindowTopLeftPoint: NSPoint = NSZeroPoint
    
    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        Static.instance = self
    }

    // MARK: - NSViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.buildViews()
        self.setupTableView()
        self.registerNibs()
    }
    
    override func viewDidAppear() {
        // self.kickTableViewStressTest()
        // self.updateStandardUserDefaults()
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // MARK: Configure Views
    func buildViews() {
        // use async to properly render border line. if not async, the line sometimes disappears
        dispatch_async(dispatch_get_main_queue(), {
            self.communityImageView.layer?.borderWidth = 0.5
            self.communityImageView.layer?.masksToBounds = true
            self.communityImageView.layer?.borderColor = NSColor.blackColor().CGColor
        })
    }
    
    func setupTableView() {
        self.tableView.doubleAction = "openUserWindow:"
        self.rowDefaultHeight = self.tableView.rowHeight
    }
    
    func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameScoreTableCellView, kScoreColumnIdentifier),
            (kNibNameUserIdTableCellView, kUserIdColumnIdentifier),
            (kNibNamePremiumTableCellView, kPremiumColumnIdentifier)]
        
        for (nibName, identifier) in nibs {
            let nib = NSNib(nibNamed: nibName, bundle: NSBundle.mainBundle())
            self.tableView.registerNib(nib!, forIdentifier: identifier)
        }
    }
    
    // MARK: Utility
    func changeShowHbIfseetnoCommands(show: Bool) {
        MessageContainer.sharedContainer.showHbIfseetnoCommands = show
        log.debug("changed show 'hbifseetno' commands: \(show)")
        
        self.rebuildFilteredMessages()
    }
    
    func changeEnableMuteUserIds(enabled: Bool) {
        MessageContainer.sharedContainer.enableMuteUserIds = enabled
        log.debug("changed enable mute userids: \(enabled)")
        
        self.rebuildFilteredMessages()
    }
    
    func changeMuteUserIds(muteUserIds: [[String: String]]) {
        MessageContainer.sharedContainer.muteUserIds = muteUserIds
        log.debug("changed mute userids: \(muteUserIds)")
        
        self.rebuildFilteredMessages()
    }
    
    func changeEnableMuteWords(enabled: Bool) {
        MessageContainer.sharedContainer.enableMuteWords = enabled
        log.debug("changed enable mute words: \(enabled)")
        
        self.rebuildFilteredMessages()
    }
    
    func changeMuteWords(muteWords: [[String: String]]) {
        MessageContainer.sharedContainer.muteWords = muteWords
        log.debug("changed mute words: \(muteWords)")
        
        self.rebuildFilteredMessages()
    }
    
    func rebuildFilteredMessages() {
        dispatch_async(dispatch_get_main_queue(), {
            self.progressIndicator.startAnimation(self)
            let shouldScroll = self.shouldTableViewScrollToBottom()
            
            MessageContainer.sharedContainer.rebuildFilteredMessages({ () -> Void in
                self.tableView.reloadData()
                
                if shouldScroll {
                    self.scrollTableViewToBottom()
                }
                self.scrollView.flashScrollers()
                
                self.progressIndicator.stopAnimation(self)
            })
        })
    }
    
    // MARK: - NSTableViewDataSource Functions
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return MessageContainer.sharedContainer.count()
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = MessageContainer.sharedContainer[row]
        
        if let cached = self.rowHeightCacher[message.messageNo] {
            return cached
        }
        
        var rowHeight: CGFloat = 0
        var content: String? = ""
        
        let commentTableColumn = self.tableView.tableColumnWithIdentifier(kCommentColumnIdentifier)!
        let commentColumnWidth = commentTableColumn.width
        rowHeight = self.commentColumnHeight(message, width: commentColumnWidth)
        
        self.rowHeightCacher[message.messageNo] = rowHeight
        
        return rowHeight
    }
    
    func commentColumnHeight(message: Message, width: CGFloat) -> CGFloat {
        let leadingSpace: CGFloat = 2
        let trailingSpace: CGFloat = 2
        let widthPadding = leadingSpace + trailingSpace

        let (content, attributes) = self.contentAndAttributesForMessage(message)
        
        let commentRect = content.boundingRectWithSize(CGSizeMake(width - widthPadding, 0),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: attributes)
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")
        
        return max(commentRect.size.height, self.rowDefaultHeight)
    }
    
    func tableViewColumnDidResize(aNotification: NSNotification) {
        let column = aNotification.userInfo?["NSTableColumn"] as NSTableColumn
        
        if column.identifier == kCommentColumnIdentifier {
            self.rowHeightCacher.removeAll(keepCapacity: false)
            self.tableView.reloadData()
        }
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var view: NSTableCellView?
        
        if let identifier = tableColumn?.identifier {
            view = tableView.makeViewWithIdentifier(identifier, owner: self) as? NSTableCellView
            view?.textField?.stringValue = ""
        }

        let message = MessageContainer.sharedContainer[row]
        
        if message.messageType == .System {
            self.configureViewForSystemMessage(message, tableColumn: tableColumn!, view: view!)
        }
        else if message.messageType == .Chat {
            self.configureViewForChat(message, tableColumn: tableColumn!, view: view!)
        }
        
        return view
    }
    
    func configureViewForSystemMessage(message: Message, tableColumn: NSTableColumn, view: NSTableCellView) {
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = (view as RoomPositionTableCellView)
            roomPositionView.roomPosition = nil
            roomPositionView.commentNo = nil
        case kScoreColumnIdentifier:
            (view as ScoreTableCellView).chat = nil
        case kCommentColumnIdentifier:
            let (content, attributes) = self.contentAndAttributesForMessage(message)
            let attributed = NSAttributedString(string: content, attributes: attributes)
            view.textField?.attributedStringValue = attributed
        case kUserIdColumnIdentifier:
            (view as UserIdTableCellView).chat = nil
        case kPremiumColumnIdentifier:
            (view as PremiumTableCellView).premium = nil
        default:
            break
        }
    }

    func configureViewForChat(message: Message, tableColumn: NSTableColumn, view: NSTableCellView) {
        let chat = message.chat!
        
        var attributed: NSAttributedString?
        
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = (view as RoomPositionTableCellView)
            roomPositionView.roomPosition = chat.roomPosition!
            roomPositionView.commentNo = chat.no!
        case kScoreColumnIdentifier:
            (view as ScoreTableCellView).chat = chat
        case kCommentColumnIdentifier:
            let (content, attributes) = self.contentAndAttributesForMessage(message)
            attributed = NSAttributedString(string: content, attributes: attributes)
        case kUserIdColumnIdentifier:
            (view as UserIdTableCellView).chat = chat
        case kPremiumColumnIdentifier:
            (view as PremiumTableCellView).premium = chat.premium!
        /*
        case kMailColumnIdentifier:
            if let mail = chat.mail {
                attributed = NSAttributedString(string: chat.mail!, attributes: UIHelper.normalCommentAttributes())
            }
         */
        default:
            break
        }

        if attributed != nil {
            view.textField?.attributedStringValue = attributed!
        }
    }
    
    // MARK: Utility
    func contentAndAttributesForMessage(message: Message) -> (NSString, [NSString: AnyObject]) {
        var content: NSString!
        var attributes: [NSString: AnyObject]!
        
        if message.messageType == .System {
            content = message.message!
            attributes = UIHelper.normalCommentAttributes()
        }
        else if message.messageType == .Chat {
            content = message.chat!.comment!
            attributes = (message.firstChat == true ? UIHelper.boldCommentAttributes() : UIHelper.normalCommentAttributes())
        }
        
        return (content, attributes)
    }
    
    // MARK: - NSControlTextEditingDelegate Functions
    func control(control: NSControl, textView: NSTextView, doCommandBySelector commandSelector: Selector) -> Bool {
        let isMovedUp = commandSelector == "moveUp:"
        let isMovedDown = commandSelector == "moveDown:"
        
        if isMovedUp || isMovedDown {
            if self.commentHistory.count == 0 {
                // nop
            }
            else {
                self.handleCommentTextFieldKeyUpDown(isMovedUp: isMovedUp, isMovedDown: isMovedDown)
            }
            
            return true
        }
        
        return false
    }
    
    func handleCommentTextFieldKeyUpDown(#isMovedUp: Bool, isMovedDown: Bool) {
        if isMovedUp && 0 <= self.commentHistoryIndex {
            self.commentHistoryIndex! -= 1
        }
        else if isMovedDown && self.commentHistoryIndex <= (self.commentHistory.count - 1) {
            self.commentHistoryIndex! += 1
        }
        
        let inValidHistoryRange = (0 <= self.commentHistoryIndex && self.commentHistoryIndex <= (self.commentHistory.count - 1))
        
        self.commentTextField.stringValue = (inValidHistoryRange ? self.commentHistory[self.commentHistoryIndex!] : "")
        
        // selectText() should be called in next run loop, http://stackoverflow.com/a/2196751
        dispatch_after(0, dispatch_get_main_queue()) {
            self.commentTextField.selectText(self)
        }
    }
    
    // MARK: - NicoUtilityDelegate Functions
    func nicoUtilityWillPrepareLive(nicoUtility: NicoUtility) {
        self.progressIndicator.startAnimation(self)
    }

    func nicoUtilityDidPrepareLive(nicoUtility: NicoUtility, user: User, live: Live) {
        if let startTime = live.startTime {
            let beginDate = NSDate(timeInterval: kDelayToShowHbIfseetnoCommands, sinceDate: startTime)
            MessageContainer.sharedContainer.beginDateToShowHbIfseetnoCommands = beginDate
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            self.liveTitleLabel.stringValue = live.title!
            
            let communityTitle = live.community.title ?? "-"
            let level = live.community.level != nil ? String(live.community.level!) : "-"
            self.communityTitleLabel.stringValue = communityTitle + " (Lv." + level + ")"
            self.roomPositionLabel.stringValue = user.roomLabel! + " - " + String(user.seatNo!)
            
            self.notificationLabel.stringValue = "Opened: ---"
            
            self.startTimers()
            self.loadThumbnail()
            self.focusCommentTextField()
        })
        
        self.logSystemMessageToTableView("Prepared live as user \(user.nickname!).")
    }
    
    func nicoUtilityDidFailToPrepareLive(nicoUtility: NicoUtility, reason: String) {
        self.logSystemMessageToTableView("Failed to prepare live.(\(reason))")
        self.progressIndicator.stopAnimation(self)
    }

    func nicoUtilityDidConnectToLive(nicoUtility: NicoUtility, roomPosition: RoomPosition) {
        if self.connectedToLive == false {
            self.connectedToLive = true
            self.logSystemMessageToTableView("Connected to live.")
            self.progressIndicator.stopAnimation(self)
        }
    }

    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat) {
        if chat.roomPosition == nil {
            return
        }

        self.logSystemMessageToTableView("Opened \(chat.roomPosition!.label()).")

        if self.openedRoomPosition == nil {
            // nop
        }
        else if chat.roomPosition!.rawValue <= self.openedRoomPosition?.rawValue {
            return
        }
        self.openedRoomPosition = chat.roomPosition
        
        dispatch_async(dispatch_get_main_queue(), {
            self.notificationLabel.stringValue = "Opened:~\(chat.roomPosition!.label())"
        })
    }

    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")
        HandleNameManager.sharedManager.extractAndUpdateHandleNameWithChat(chat)
        self.appendTableView(chat)
        
        for userWindowController in self.userWindowControllers {
            if chat.userId == userWindowController.userId {
                dispatch_async(dispatch_get_main_queue(), {
                    userWindowController.reloadMessages()
                })
            }
        }
    }
    
    func nicoUtilityDidGetKickedOut(nicoUtility: NicoUtility) {
        self.logSystemMessageToTableView("Got kicked out...")
    }
    
    func nicoUtilityWillReconnectToLive(nicoUtility: NicoUtility) {
        self.logSystemMessageToTableView("Reconnecting...")
    }
    
    func nicoUtilityDidDisconnect(nicoUtility: NicoUtility) {
        self.logSystemMessageToTableView("Live closed.")
        self.stopTimers()
        self.connectedToLive = false
        self.openedRoomPosition = nil
    }
    
    func nicoUtilityDidReceiveHeartbeat(nicoUtility: NicoUtility, heartbeat: Heartbeat) {
        self.updateHeartbeatInformation(heartbeat)
    }
    
    // MARK: System Message Utility
    func logSystemMessageToTableView(message: String) {
        self.appendTableView(message)
    }
    
    // MARK: Chat Append Utility
    func appendTableView(chatOrSystemMessage: AnyObject) {
        dispatch_async(dispatch_get_main_queue(), {
            let shouldScroll = self.shouldTableViewScrollToBottom()
            
            let (appended, count) = MessageContainer.sharedContainer.append(chatOrSystemMessage: chatOrSystemMessage)
            
            if appended {
                let rowIndex = count - 1
                
                self.tableView.insertRowsAtIndexes(NSIndexSet(index: rowIndex), withAnimation: .EffectNone)
                // self.logChat(chatOrSystemMessage)
                
                if shouldScroll {
                    self.scrollTableViewToBottom()
                }
                
                self.scrollView.flashScrollers()
            }
        })
    }
    
    func logMessage(message: Message) {
        var content: String?
        
        if message.messageType == .System {
            content = message.message
        }
        else if message.messageType == .Chat {
            content = message.chat!.comment
        }
        
        log.debug("[ " + content! + " ]")
    }
    
    func shouldTableViewScrollToBottom() -> Bool {
        if 0 < self.currentScrollAnimationCount {
            return self.lastShouldScrollToBottom
        }
        
        let viewRect = self.scrollView.contentView.documentRect
        let visibleRect = self.scrollView.contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")
        
        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10

        let shouldScroll = (bottomY <= (offsetBottomY + allowance))
        self.lastShouldScrollToBottom = shouldScroll
        
        return shouldScroll
    }
    
    func scrollTableViewToBottom(animated: Bool = false) {
        let clipView = self.scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        let origin = NSMakePoint(x, y)
        
        if !animated {
            // note: do not use scrollRowToVisible here.
            // scroll will be sometimes stopped when very long comment arrives.
            // self.tableView.scrollRowToVisible(self.tableView.numberOfRows - 1)
            clipView.setBoundsOrigin(origin)
        }
        else {
            // http://stackoverflow.com/questions/19399242/soft-scroll-animation-nsscrollview-scrolltopoint
            self.currentScrollAnimationCount += 1
            // log.debug("start scroll animation:\(self.currentScrollAnimationCount)")
            
            NSAnimationContext.beginGrouping()
            NSAnimationContext.currentContext().duration = 0.5
            
            NSAnimationContext.currentContext().completionHandler = { () -> Void in
                self.currentScrollAnimationCount -= 1
                // self.log.debug("  end scroll animation:\(self.currentScrollAnimationCount)")
            }
            
            clipView.animator().setBoundsOrigin(origin)
            // self.scrollView.reflectScrolledClipView(clipView)
            
            NSAnimationContext.endGrouping()
        }
    }
    
    // MARK: - UserWindowControllerDelegate Functions
    func userWindowControllerDidClose(userWindowController: UserWindowController) {
        log.debug("")
        
        if let index = find(self.userWindowControllers, userWindowController) {
            self.userWindowControllers.removeAtIndex(index)
        }
    }
    
    // MARK: - Public Functions
    func showHandleNameAddViewController(chat: Chat) {
        let storyboard = NSStoryboard(name: kStoryboardNameMainWindowController, bundle: nil)!
        let handleNameAddViewController = storyboard.instantiateControllerWithIdentifier(kStoryboardIdHandleNameAddViewController) as HandleNameAddViewController
        
        handleNameAddViewController.handleName = (self.defaultHandleNameWithChat(chat) ?? "")
        handleNameAddViewController.completion = { (cancelled: Bool, handleName: String?) -> Void in
            if !cancelled {
                HandleNameManager.sharedManager.updateHandleNameWithChat(chat, handleName: handleName!)
                MainViewController.sharedInstance.refreshHandleName()
            }
            
            self.dismissViewController(handleNameAddViewController)
            // TODO: deinit in handleNameViewController is not called after this completion
        }
        
        self.presentViewControllerAsSheet(handleNameAddViewController)
    }
    
    func defaultHandleNameWithChat(chat: Chat) -> String? {
        var defaultHandleName: String?
        
        if let handleName = HandleNameManager.sharedManager.handleNameForChat(chat) {
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
        self.tableView.reloadData()
        self.scrollView.flashScrollers()
    }
    
    // MARK: Hotkeys
    func focusLiveTextField() {
        self.liveTextField.becomeFirstResponder()
    }

    func focusCommentTextField() {
        self.commentTextField.becomeFirstResponder()
    }
    
    // MARK: - Internal Functions
    func initializeHandleNameManager() {
        self.progressIndicator.startAnimation(self)
        
        // force to invoke setup methods in HandleNameManager()
        HandleNameManager.sharedManager
        
        self.progressIndicator.stopAnimation(self)
    }
    
    // MARK: Live Info Updater
    func loadThumbnail() {
        NicoUtility.sharedInstance.loadThumbnail { (imageData) -> (Void) in
            dispatch_async(dispatch_get_main_queue(), {
                if imageData == nil {
                    return
                }
                
                self.communityImageView.image = NSImage(data: imageData!)
            })
        }
    }
    
    func updateHeartbeatInformation(heartbeat: Heartbeat) {
        if heartbeat.status != .Ok {
            return
        }
        
        let visitors = String(heartbeat.watchCount!).numberStringWithSeparatorComma()!
        let comments = String(heartbeat.commentCount!).numberStringWithSeparatorComma()!
        
        var remaining = "-"
        if let free = heartbeat.freeSlotNum {
            remaining = free == 0 ? "満員" : String(free).numberStringWithSeparatorComma()!
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            self.visitorsLabel.stringValue = "Visitors: " + visitors
            self.commentsLabel.stringValue = "Comments: " + comments
            self.remainingSeatsLabel.stringValue = "Seats: " + remaining
        })
    }
    
    // MARK: Control Handlers
    @IBAction func grabUrlFromBrowser(sender: AnyObject) {
        if let url = BrowserHelper.urlFromBrowser(.Chrome) {
            self.liveTextField.stringValue = url
            self.connectLive(self)
        }
    }
    
    @IBAction func connectLive(sender: AnyObject) {
        self.initializeHandleNameManager()
        
        if let liveNumber = MainViewController.extractLiveNumber(self.liveTextField.stringValue) {
            self.clearAllChats()

            self.communityImageView.image = NSImage(named: kCommunityImageDefaultName)

            NicoUtility.sharedInstance.delegate = self
            
            let defaults = NSUserDefaults.standardUserDefaults()
            let sessionManagementType = SessionManagementType(rawValue: defaults.integerForKey(Parameters.SessionManagement))!
            
            switch sessionManagementType {
            case .Login:
                if let account = KeychainUtility.accountInKeychain() {
                    let mailAddress = account.mailAddress
                    let password = account.password
                    NicoUtility.sharedInstance.connectToLive(liveNumber, mailAddress: mailAddress, password: password)
                }
                
            case .Chrome:
                NicoUtility.sharedInstance.connectToLive(liveNumber, browserType: .Chrome)
                
            default:
                break
            }
        }
    }
    
    @IBAction func comment(sender: AnyObject) {
        let comment = self.commentTextField.stringValue
        if countElements(comment) == 0 {
            return
        }
        
        let anonymously = NSUserDefaults.standardUserDefaults().boolForKey(Parameters.CommentAnonymously)
        NicoUtility.sharedInstance.comment(comment, anonymously: anonymously) { (comment: String?) -> Void in
            if comment == nil {
                self.logSystemMessageToTableView("Failed to comment.")
            }
        }
        self.commentTextField.stringValue = ""
        
        if self.commentHistory.count == 0 || self.commentHistory.last != comment {
            self.commentHistory.append(comment)
            self.commentHistoryIndex = self.commentHistory.count
        }
    }
    
    func openUserWindow(sender: AnyObject?) {
        let clickedRow = self.tableView.clickedRow
        
        if clickedRow == -1 {
            return
        }
        
        let message = MessageContainer.sharedContainer[clickedRow]
        
        if message.messageType != .Chat || message.chat?.userId == nil {
            return
        }
        
        let chat = message.chat!

        var userWindowController: UserWindowController?
        
        // check if user window exists?
        for existing in self.userWindowControllers {
            if chat.userId == existing.userId {
                userWindowController = existing
                log.debug("existing userwc found, use it:\(userWindowController)")
                break
            }
        }
        
        if userWindowController == nil {
            // not exist, so create and cache it
            userWindowController = UserWindowController.generateInstanceWithDelegate(self, userId: chat.userId!)
            self.positionUserWindow(userWindowController!.window!)
            log.debug("no existing userwc found, create it:\(userWindowController)")
            self.userWindowControllers.append(userWindowController!)
        }
        
        userWindowController!.showWindow(self)
    }
    
    private func positionUserWindow(userWindow: NSWindow) {
        var topLeftPoint: NSPoint = self.nextUserWindowTopLeftPoint

        if self.userWindowControllers.count == 0 {
            topLeftPoint = kUserWindowDefautlTopLeftPoint
        }
        
        self.nextUserWindowTopLeftPoint = userWindow.cascadeTopLeftFromPoint(topLeftPoint)
    }
    
    // MARK: Timer Functions
    func startTimers() {
        self.elapsedTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "displayElapsed:", userInfo: nil, repeats: true)
        self.activeTimer = NSTimer.scheduledTimerWithTimeInterval(kCalculateActiveInterval, target: self, selector: "calculateActive:", userInfo: nil, repeats: true)
    }
    
    func stopTimers() {
        if self.elapsedTimer != nil {
            self.elapsedTimer!.invalidate()
            self.elapsedTimer = nil
        }
        
        if self.activeTimer != nil {
            self.activeTimer!.invalidate()
            self.activeTimer = nil
        }
    }
    
    func displayElapsed(timer: NSTimer) {
        var display = "--:--:--"
        
        if let startTime = NicoUtility.sharedInstance.live?.startTime {
            var prefix = ""
            var elapsed = NSDate().timeIntervalSinceDate(startTime)
            
            if elapsed < 0 {
                prefix = "-"
                elapsed = abs(elapsed)
            }
            
            let hour = String(format:"%02d", Int(elapsed / 3600))
            let minute = String(format:"%02d", Int((elapsed / 60) % 60))
            let second = String(format:"%02d", Int(elapsed % 60))
            
            display = "\(prefix)\(hour):\(minute):\(second)"
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            self.elapsedLabel.stringValue = "Elapsed: " + display
        })
    }
    
    func calculateActive(timer: NSTimer) {
        MessageContainer.sharedContainer.calculateActive { (active: Int?) -> (Void) in
            if active == nil {
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.activeLabel.stringValue = "Active:\(active!)"
            })
        }
    }
    
    // MARK: Misc Utility
    func clearAllChats() {
        MessageContainer.sharedContainer.removeAll()
        self.rowHeightCacher.removeAll(keepCapacity: false)
        self.tableView.reloadData()
    }
    
    class func extractLiveNumber(url: String) -> Int? {
        let liveNumberPattern = "\\d{9,}"
        var pattern: String

        pattern = "http:\\/\\/live\\.nicovideo\\.jp\\/watch\\/lv(" + liveNumberPattern + ").*"

        if let extracted = url.extractRegexpPattern(pattern) {
            return extracted.toInt()
        }

        pattern = "lv(" + liveNumberPattern + ")"

        if let extracted = url.extractRegexpPattern(pattern) {
            return extracted.toInt()
        }

        pattern = "(" + liveNumberPattern + ")"

        if let extracted = url.extractRegexpPattern(pattern) {
            return extracted.toInt()
        }

        return nil
    }
}
