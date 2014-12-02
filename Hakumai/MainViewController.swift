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

let kRoomPositionColumnIdentifier = "RoomPositionColumn"
let kScoreColumnIdentifier = "ScoreColumn"
let kCommentColumnIdentifier = "CommentColumn"
let kUserIdColumnIdentifier = "UserIdColumn"
let kPremiumColumnIdentifier = "PremiumColumn"
let kMailColumnIdentifier = "MailColumn"

let kCalculateActiveInterval: NSTimeInterval = 3

class MainViewController: NSViewController, NicoUtilityProtocol, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var liveTextField: NSTextField!
    
    @IBOutlet weak var communityImageView: NSImageView!
    @IBOutlet weak var liveTitleLabel: NSTextField!
    @IBOutlet weak var communityTitleLabel: NSTextField!
    @IBOutlet weak var roomPositionLabel: NSTextField!
    
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var activeLabel: NSTextField!
    @IBOutlet weak var notificationLabel: NSTextField!
    @IBOutlet weak var commentTextField: NSTextField!

    struct Static {
        static var instance: MainViewController!
    }
    
    let log = XCGLogger.defaultInstance()

    var chats: [Chat] = []

    // row-height cache
    var RowHeightCacher = Dictionary<Int, CGFloat>()
    var lastShouldScrollToBottom = true
    var currentScrollAnimationCount = 0
    
    var activeTimer: NSTimer?

    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        Static.instance = self
    }

    class func instance() -> MainViewController? {
        return Static.instance
    }

    // MARK: - UIViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.communityImageView.layer?.borderWidth = 1.0
        self.communityImageView.layer?.borderColor = NSColor.blackColor().CGColor

        self.registerNibs()
        
        // TODO: disabled for test
        self.activeTimer = NSTimer.scheduledTimerWithTimeInterval(kCalculateActiveInterval, target: self, selector: "calculateActive:", userInfo: nil, repeats: true)
    }
    
    func registerNibs() {
        let roomPositionTableCellViewNib = NSNib(nibNamed: kNibNameRoomPositionTableCellView, bundle: NSBundle.mainBundle())
        self.tableView.registerNib(roomPositionTableCellViewNib!, forIdentifier: kRoomPositionColumnIdentifier)
        
        let scoreTableCellViewNib = NSNib(nibNamed: kNibNameScoreTableCellView, bundle: NSBundle.mainBundle())
        self.tableView.registerNib(scoreTableCellViewNib!, forIdentifier: kScoreColumnIdentifier)
        
        let userIdTableCellViewNib = NSNib(nibNamed: kNibNameUserIdTableCellView, bundle: NSBundle.mainBundle())
        self.tableView.registerNib(userIdTableCellViewNib!, forIdentifier: kUserIdColumnIdentifier)
    }
    
    override func viewDidAppear() {
        // self.kickParallelTableViewStressTest(5, interval: 0.5, count: 100000)
        // self.kickParallelTableViewStressTest(4, interval: 2, count: 100000)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // MARK: - NSTableViewDataSource Functions
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return ChatContainer.sharedContainer.count()
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if let cached = self.RowHeightCacher[row] {
            return cached
        }
        
        var rowHeight: CGFloat = 0
        var content: String? = ""
        
        let chatOrSystemMessage: AnyObject = ChatContainer.sharedContainer[row]
        
        if let message = chatOrSystemMessage as? SystemMessage {
            content = message.message
        }
        else if let chat = chatOrSystemMessage as? Chat {
            content = chat.comment
        }
        
        let commentTableColumn = self.tableView.tableColumnWithIdentifier(kCommentColumnIdentifier)!
        let commentColumnWidth = commentTableColumn.width
        rowHeight = self.commentColumnHeight(content!, width: commentColumnWidth)
        
        self.RowHeightCacher[row] = rowHeight
        
        return rowHeight
    }
    
    func commentColumnHeight(comment: String, width: CGFloat) -> CGFloat {
        let systemFontSize: CGFloat = 13.0
        
        let leadingSpace: CGFloat = 2
        let trailingSpace: CGFloat = 2
        let widthPadding = leadingSpace + trailingSpace
        
        let attributes = [NSFontAttributeName: NSFont.systemFontOfSize(systemFontSize),
            NSParagraphStyleAttributeName: NSParagraphStyle.defaultParagraphStyle()]
        let commentRect = (comment as NSString).boundingRectWithSize(CGSizeMake(width - widthPadding, 0),
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

        let chatOrSystemMessage: AnyObject = ChatContainer.sharedContainer[row]
        
        if let message = chatOrSystemMessage as? SystemMessage {
            self.configureSystemMessageView(message, tableColumn: tableColumn!, view: view!)
        }
        else if let chat = chatOrSystemMessage as? Chat {
            self.configureChatView(chat, tableColumn: tableColumn!, view: view!)
        }
        
        return view
    }
    
    func configureSystemMessageView(message: SystemMessage, tableColumn: NSTableColumn, view: NSTableCellView) {
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = (view as RoomPositionTableCellView)
            roomPositionView.roomPosition = nil
            roomPositionView.commentNo = nil
        case kScoreColumnIdentifier:
            (view as ScoreTableCellView).score = nil
        case kCommentColumnIdentifier:
            view.textField?.stringValue = message.message
        case kUserIdColumnIdentifier:
            (view as UserIdTableCellView).userId = nil
        default:
            break
        }
    }
    
    func configureChatView(chat: Chat, tableColumn: NSTableColumn, view: NSTableCellView) {
        var content: String? = nil
        
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = (view as RoomPositionTableCellView)
            roomPositionView.roomPosition = chat.roomPosition!
            roomPositionView.commentNo = chat.no!
        case kScoreColumnIdentifier:
            (view as ScoreTableCellView).score = chat.score!
        case kCommentColumnIdentifier:
            content = chat.comment
        case kUserIdColumnIdentifier:
            (view as UserIdTableCellView).userId = chat.userId
        case kPremiumColumnIdentifier:
            content = chat.premium?.label()
        case kMailColumnIdentifier:
            content = chat.mail
        default:
            break
        }

        if content != nil {
            view.textField?.stringValue = content!
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
        
        dispatch_async(dispatch_get_main_queue(), {
            // nop
        })
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
    }
    
    // MARK: System Message Utility
    func logSystemMessageToTableView(message: String) {
        let systemMessage = SystemMessage(message: "[ " + message + " ]")
        self.appendTableView(systemMessage)
    }
    
    // MARK: Chat Append Utility
    func shouldIgnoreChat(chat: Chat) -> Bool {
        if chat.comment?.hasPrefix("/hb ifseetno ") == true {
            return true
        }
        
        if (chat.premium == .System || chat.premium == .Caster || chat.premium == .BSP) &&
            chat.roomPosition != .Arena {
            return true
        }
        
        return false
    }
    
    func appendTableView(chatOrSystemMessage: AnyObject) {
        dispatch_async(dispatch_get_main_queue(), {
            let shouldScroll = self.shouldTableViewScrollToBottom()
            
            let rowIndex = ChatContainer.sharedContainer.append(chatOrSystemMessage: chatOrSystemMessage) - 1
            self.tableView.insertRowsAtIndexes(NSIndexSet(index: rowIndex), withAnimation: .EffectNone)
            self.logChatOrSystemMessage(chatOrSystemMessage)
            
            if shouldScroll {
                // self.tableView.scrollRowToVisible(rowIndex)
                self.scrollMoveToBottom()
            }
            
            self.scrollView.flashScrollers()
        })
    }
    
    func logChatOrSystemMessage(chatOrSystemMessage: AnyObject) {
        var content = ""
        
        if let chat = chatOrSystemMessage as? Chat {
            content = chat.comment!
        }
        else if let systemMessage = chatOrSystemMessage as? SystemMessage {
            content = systemMessage.message
        }
        
        log.debug("[ " + content + " ]")
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
    
    // http://stackoverflow.com/questions/19399242/soft-scroll-animation-nsscrollview-scrolltopoint
    func scrollMoveToBottom() {
        self.currentScrollAnimationCount += 1
        // log.debug("start scroll animation:\(self.currentScrollAnimationCount)")
        
        NSAnimationContext.beginGrouping()
        NSAnimationContext.currentContext().duration = 0.3
        
        NSAnimationContext.currentContext().completionHandler = {() -> Void in
            self.currentScrollAnimationCount -= 1
            // self.log.debug("  end scroll animation:\(self.currentScrollAnimationCount)")
        }
        
        let clipView = self.scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        
        clipView.animator().setBoundsOrigin(NSMakePoint(x, y))
        // self.scrollView.reflectScrolledClipView(clipView)
        
        NSAnimationContext.endGrouping()
    }
    
    // MARK: - Live Info Loader
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
    
    // MARK: - Comment TextField Action
    @IBAction func comment(sender: AnyObject) {
        NicoUtility.sharedInstance.comment(self.commentTextField.stringValue)
        
        self.commentTextField.stringValue = ""
    }
    
    // MARK: - Button Handlers
    @IBAction func connectLive(sender: AnyObject) {
        if let liveNumber = MainViewController.extractLiveNumber(self.liveTextField.stringValue) {
            self.clearAllChats()

            NicoUtility.sharedInstance.delegate = self
            NicoUtility.sharedInstance.connect(liveNumber)
        }
    }

    // MARK: - Timer Handlers
    func calculateActive(timer: NSTimer) {
        ChatContainer.sharedContainer.calculateActive { (active: Int?) -> (Void) in
            if active == nil {
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.activeLabel.stringValue = "active:\(active!)"
            })
        }
    }

    // MARK: - Menu Handlers
    func focusLiveTextField() {
        self.liveTextField.becomeFirstResponder()
    }
    
    func focusCommentTextField() {
        self.commentTextField.becomeFirstResponder()
    }

    // MARK: - Internal Functions
    func clearAllChats() {
        self.RowHeightCacher.removeAll(keepCapacity: false)
        ChatContainer.sharedContainer.removeAll()
        self.tableView.reloadData()
    }
    
    // MARK: - Misc Utility
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
