//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

let kNibNameRoomPositionTableCellView = "RoomPositionTableCellView"
let kNibNameScoreTableCellView = "ScoreTableCellView"
let kNibNameUserIdTableCellView = "UserIdTableCellView"
let kNibNamePremiumTableCellView = "PremiumTableCellView"

let kRoomPositionColumnIdentifier = "RoomPositionColumn"
let kScoreColumnIdentifier = "ScoreColumn"
let kCommentColumnIdentifier = "CommentColumn"
let kUserIdColumnIdentifier = "UserIdColumn"
let kPremiumColumnIdentifier = "PremiumColumn"
let kMailColumnIdentifier = "MailColumn"

let kCalculateActiveInterval: NSTimeInterval = 3

class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate, NicoUtilityProtocol {
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

    var chats = [Chat]()

    // row-height cache
    var RowHeightCacher = [Int: CGFloat]()
    var lastShouldScrollToBottom = true
    var currentScrollAnimationCount = 0
    
    var commentHistory = [String]()
    var commentHistoryIndex: Int?
    
    var elapsedTimer: NSTimer?
    var activeTimer: NSTimer?

    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        Static.instance = self
    }

    // MARK: - UIViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.buildViews()
        self.registerNibs()
        self.configureMessageContainer()
        self.addObserverForUserDefaults()
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
        self.communityImageView.layer?.borderWidth = 1.0
        self.communityImageView.layer?.masksToBounds = true
        self.communityImageView.layer?.borderColor = NSColor.blackColor().CGColor
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
    
    func addObserverForUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        defaults.addObserver(self, forKeyPath: Parameters.ShowIfseetnoCommands, options: .New, context: nil)
    }
    
    func configureMessageContainer() {
        // NSUserDefaults.standardUserDefaults().boolForKey(kParameterShowIfseetnoCommands)
    }
    
    // MARK: - KVO Functions
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        // log.debug("detected observing value changed: key[\(keyPath)]")
        
        if keyPath == Parameters.ShowIfseetnoCommands {
            if let newValue = change["new"] as? Bool {
                // log.debug("\(newValue)")
                
                // use explicit next runloop to complete animating checkbox
                dispatch_after(0, dispatch_get_main_queue()) { () -> Void in
                    self.changeShowHbIfseetnoCommands(newValue)
                }
            }
        }
    }
    
    func changeShowHbIfseetnoCommands(show: Bool) {
        self.progressIndicator.startAnimation(self)
        
        let shouldScroll = self.shouldTableViewScrollToBottom()
        
        MessageContainer.sharedContainer.showHbIfseetnoCommands = show
        
        self.RowHeightCacher.removeAll(keepCapacity: false)
        self.tableView.reloadData()
        
        if shouldScroll {
            self.scrollMoveToBottom()
        }
        
        self.scrollView.flashScrollers()
        
        self.progressIndicator.stopAnimation(self)
    }
    
    // MARK: - NSTableViewDataSource Functions
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return MessageContainer.sharedContainer.count()
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if let cached = self.RowHeightCacher[row] {
            return cached
        }
        
        var rowHeight: CGFloat = 0
        var content: String? = ""
        
        let message = MessageContainer.sharedContainer[row]
        
        let commentTableColumn = self.tableView.tableColumnWithIdentifier(kCommentColumnIdentifier)!
        let commentColumnWidth = commentTableColumn.width
        rowHeight = self.commentColumnHeight(message, width: commentColumnWidth)
        
        self.RowHeightCacher[row] = rowHeight
        
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
        
        return commentRect.size.height
    }
    
    func tableViewColumnDidResize(aNotification: NSNotification) {
        self.RowHeightCacher.removeAll(keepCapacity: false)
        self.tableView.reloadData()
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
            (view as ScoreTableCellView).score = nil
        case kCommentColumnIdentifier:
            let (content, attributes) = self.contentAndAttributesForMessage(message)
            let attributed = NSAttributedString(string: content, attributes: attributes)
            view.textField?.attributedStringValue = attributed
        case kUserIdColumnIdentifier:
            (view as UserIdTableCellView).userId = nil
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
            (view as ScoreTableCellView).score = chat.score!
        case kCommentColumnIdentifier:
            let (content, attributes) = self.contentAndAttributesForMessage(message)
            attributed = NSAttributedString(string: content, attributes: attributes)
        case kUserIdColumnIdentifier:
            (view as UserIdTableCellView).userId = chat.userId
        case kPremiumColumnIdentifier:
            (view as PremiumTableCellView).premium = chat.premium!
        case kMailColumnIdentifier:
            if let mail = chat.mail {
                attributed = NSAttributedString(string: chat.mail!, attributes: UIHelper.normalCommentAttributes())
            }
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
        dispatch_after(0, dispatch_get_main_queue()) { () -> Void in
            self.commentTextField.selectText(self)
        }
    }
    
    // MARK: - NicoUtilityDelegate Functions
    func nicoUtilityDidPrepareLive(nicoUtility: NicoUtility, user: User, live: Live) {
        dispatch_async(dispatch_get_main_queue(), {
            self.liveTitleLabel.stringValue = live.title!
            self.communityTitleLabel.stringValue = live.community.title! + " (Lv." + String(live.community.level!) + ")"
            self.roomPositionLabel.stringValue = user.roomLabel! + " - " + String(user.seatNo!)
        })
        
        self.loadThumbnail()
        self.focusCommentTextField()
        
        self.logSystemMessageToTableView("放送情報を取得しました.")
    }

    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition) {
        log.info("started listening \(roomPosition.label()).")
        
        if roomPosition == .Arena {
            self.startTimers()
        }
    }

    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat) {
        if let roomPositionLabel = chat.roomPosition?.label() {
            dispatch_async(dispatch_get_main_queue(), {
                self.notificationLabel.stringValue = "opened:\(roomPositionLabel)"
            })
            
            self.logSystemMessageToTableView("\(roomPositionLabel)がオープンしました.")
        }
    }

    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")

        if self.shouldIgnoreChat(chat) {
            return
        }
        
        self.appendTableView(chat)
    }
    
    func nicoUtilityDidFinishListening(nicoUtility: NicoUtility) {
        self.logSystemMessageToTableView("放送が終了しました.")
        self.stopTimers()
    }
    
    func nicoUtilityDidReceiveHeartbeat(nicoUtility: NicoUtility, heartbeat: Heartbeat) {
        self.updateHeartbeatInformation(heartbeat)
    }
    
    // MARK: System Message Utility
    func logSystemMessageToTableView(message: String) {
        self.appendTableView(message)
    }
    
    // MARK: Chat Append Utility
    func shouldIgnoreChat(chat: Chat) -> Bool {
        if (chat.premium == .System || chat.premium == .Caster || chat.premium == .Operator || chat.premium == .BSP) &&
            chat.roomPosition != .Arena {
            return true
        }
        
        return false
    }
    
    func appendTableView(chatOrSystemMessage: AnyObject) {
        dispatch_async(dispatch_get_main_queue(), {
            let shouldScroll = self.shouldTableViewScrollToBottom()
            
            let (appended, count) = MessageContainer.sharedContainer.append(chatOrSystemMessage: chatOrSystemMessage)
            
            if appended {
                let rowIndex = count - 1
                
                self.tableView.insertRowsAtIndexes(NSIndexSet(index: rowIndex), withAnimation: .EffectNone)
                // self.logChat(chatOrSystemMessage)
                
                if shouldScroll {
                    self.scrollMoveToBottom()
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
    
    func scrollMoveToBottom(animated: Bool = false) {
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
            
            NSAnimationContext.currentContext().completionHandler = {() -> Void in
                self.currentScrollAnimationCount -= 1
                // self.log.debug("  end scroll animation:\(self.currentScrollAnimationCount)")
            }
            
            clipView.animator().setBoundsOrigin(origin)
            // self.scrollView.reflectScrolledClipView(clipView)
            
            NSAnimationContext.endGrouping()
        }
    }
    
    // MARK: - Live Info Updater
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
            self.remainingSeatsLabel.stringValue = "Remaining Seats: " + remaining
        })
    }
    
    // MARK: - Comment TextField Action
    @IBAction func comment(sender: AnyObject) {
        let comment = self.commentTextField.stringValue
        if countElements(comment) == 0 {
            return
        }

        NicoUtility.sharedInstance.comment(comment)
        self.commentTextField.stringValue = ""
        
        if self.commentHistory.count == 0 || self.commentHistory.last != comment {
            self.commentHistory.append(comment)
            self.commentHistoryIndex = self.commentHistory.count
        }
    }
    
    // MARK: - Control Handlers
    @IBAction func connectLive(sender: AnyObject) {
        if let liveNumber = MainViewController.extractLiveNumber(self.liveTextField.stringValue) {
            self.clearAllChats()

            NicoUtility.sharedInstance.delegate = self
            NicoUtility.sharedInstance.connect(liveNumber)
        }
    }
    
    func focusLiveTextField() {
        self.liveTextField.becomeFirstResponder()
    }
    
    func focusCommentTextField() {
        self.commentTextField.becomeFirstResponder()
    }

    // MARK: - Timer Functions
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
    
    // MARK: Handlers
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
                self.activeLabel.stringValue = "active:\(active!)"
            })
        }
    }
    
    // MARK: - Internal Functions
    func clearAllChats() {
        MessageContainer.sharedContainer.removeAll()
        self.RowHeightCacher.removeAll(keepCapacity: false)
        self.tableView.reloadData()
    }
    
    // MARK: Misc Utility
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
