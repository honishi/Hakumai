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
    
    var activeTimer: NSTimer?
    var calculatingActive: Bool = false

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

        self.registerNibs()
        
        // TODO: disabled for test
        self.activeTimer = NSTimer.scheduledTimerWithTimeInterval(kCalculateActiveInterval, target: self, selector: "calculateActive:", userInfo: nil, repeats: true)
    }
    
    func registerNibs() {
        let roomPositionTableCellViewNib = NSNib(nibNamed: kNibNameRoomPositionTableCellView, bundle: NSBundle.mainBundle())
        self.tableView.registerNib(roomPositionTableCellViewNib!, forIdentifier: kRoomPositionColumnIdentifier)
        
        let scoreTableCellViewNib = NSNib(nibNamed: kNibNameScoreTableCellView, bundle: NSBundle.mainBundle())
        self.tableView.registerNib(scoreTableCellViewNib!, forIdentifier: kScoreColumnIdentifier)
    }
    
    override func viewDidAppear() {
        // self.kickParallelTableViewStressTest(5, interval: 0.5, count: 100000)
        self.kickParallelTableViewStressTest(4, interval: 2, count: 100000)
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
        
        let systemFontSize: CGFloat = 13.0
        let cellSpacingWidth: CGFloat = 6.0
        let cellSpacingHeight: CGFloat = 2.0
        
        let comment = ChatContainer.sharedContainer[row].comment
        
        let commentTableColumn = self.tableView.tableColumnWithIdentifier(kCommentColumnIdentifier)
        let commentColumnWidth = commentTableColumn?.width
        
        let attributes = [NSFontAttributeName: NSFont.systemFontOfSize(systemFontSize)]
        let commentRect = (comment! as NSString).boundingRectWithSize(CGSizeMake(commentColumnWidth! - cellSpacingWidth, 0),
            options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: nil)
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")
        
        let rowHeight = commentRect.size.height + cellSpacingHeight
        self.RowHeightCacher[row] = rowHeight
        
        return rowHeight
    }
    
    func tableViewColumnDidResize(aNotification: NSNotification) {
        self.RowHeightCacher.removeAll(keepCapacity: false)
        self.tableView.reloadData()
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var content: String?
        var view: NSTableCellView?
        
        if let identifier = tableColumn?.identifier {
            view = tableView.makeViewWithIdentifier(identifier, owner: self) as? NSTableCellView
        }

        let chat = ChatContainer.sharedContainer[row]

        if tableColumn?.identifier == kRoomPositionColumnIdentifier {
            let roomPositionView = (view as RoomPositionTableCellView)
            roomPositionView.roomPosition = chat.roomPosition!
            roomPositionView.commentNo = chat.no!
        }
        else if tableColumn?.identifier == kScoreColumnIdentifier {
            (view as ScoreTableCellView).score = chat.score!
        }
        else if tableColumn?.identifier == kCommentColumnIdentifier {
            content = chat.comment
        }
        else if tableColumn?.identifier == kUserIdColumnIdentifier {
            content = chat.userId
        }
        else if tableColumn?.identifier == kPremiumColumnIdentifier {
            content = chat.premium?.label()
        }
        else if tableColumn?.identifier == kMailColumnIdentifier {
            content = chat.mail
        }
        
        if content == nil {
            content = ""
        }
        
        view?.textField?.stringValue = content!
        
        return view
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
    }

    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition) {
        log.info("started listening \(roomPosition.label()).")
        
        dispatch_async(dispatch_get_main_queue(), {
            // nop
        })
    }

    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat) {
        dispatch_async(dispatch_get_main_queue(), {
            if let roomPositionLabel = chat.roomPosition?.label() {
                self.notificationLabel.stringValue = "opened:\(roomPositionLabel)"
            }
        })
    }

    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")
        
        if chat.comment?.hasPrefix("/hb ifseetno ") == true {
            return
        }
        
        ChatContainer.sharedContainer.append(chat)
        
        func shouldTableViewScrollToBottom() -> Bool {
            let viewRect = self.scrollView.contentView.documentRect
            let visibleRect = self.scrollView.contentView.documentVisibleRect
            // log.debug("\(viewRect)-\(visibleRect)")
            
            let bottomY = viewRect.size.height
            let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
            let allowance: CGFloat = 10
            
            return (bottomY <= (offsetBottomY + allowance))
        }
        
        let shouldScroll = shouldTableViewScrollToBottom()
        
        dispatch_async(dispatch_get_main_queue(), {
            self.tableView.reloadData()
            
            if shouldScroll {
                self.tableView.scrollRowToVisible(ChatContainer.sharedContainer.count() - 1)
            }
            
            self.scrollView.flashScrollers()
        })
    }
    
    func nicoUtilityDidFinishListening(nicoUtility: NicoUtility) {
        dispatch_async(dispatch_get_main_queue(), {
            ChatContainer.sharedContainer.removeAll()
            self.tableView.reloadData()
        })
    }

    // MARK: - Live Info Loader
    func loadThumbnail() {
        NicoUtility.sharedInstance().loadThumbnail { (imageData) -> (Void) in
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
        NicoUtility.sharedInstance().comment(self.commentTextField.stringValue)
        
        self.commentTextField.stringValue = ""
    }
    
    // MARK: - Button Handlers
    @IBAction func connectLive(sender: AnyObject) {
        if let liveNumber = MainViewController.extractLiveNumber(self.liveTextField.stringValue) {
            NicoUtility.sharedInstance().delegate = self
            NicoUtility.sharedInstance().connect(liveNumber)
        }
    }

    // MARK: - Timer Handlers
    func calculateActive(timer: NSTimer) {
        if self.calculatingActive {
            log.debug("skip calcurating active")
            return
        }
        self.calculatingActive = true

        // log.debug("calcurating active")
        
        let qualityOfServiceClass = Int(QOS_CLASS_BACKGROUND.value)
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)

        dispatch_async(backgroundQueue, {
            var activeUsers = Dictionary<String, Bool>()
            let tenMinutesAgo = NSDate(timeIntervalSinceNow: (Double)(-10 * 60))

            self.log.debug("start counting active")
            
            for var i = ChatContainer.sharedContainer.count(); 0 < i ; i-- {
                let chat = ChatContainer.sharedContainer[i - 1]
                
                if chat.date == nil || chat.userId == nil {
                    continue
                }
                
                // is "chat.date < tenMinutesAgo" ?
                if chat.date!.compare(tenMinutesAgo) == .OrderedAscending {
                    break
                }
                
                activeUsers[chat.userId!] = true
            }

            self.log.debug("end counting active")
            
            dispatch_async(dispatch_get_main_queue(), {
                self.activeLabel.stringValue = "active:\(activeUsers.count)"
                
                self.calculatingActive = false
                // self.log.debug("finished to calcurate active")
            })
        })
    }

    // MARK: - Menu Handlers
    func focusLiveTextField() {
        self.liveTextField.becomeFirstResponder()
    }
    
    func focusCommentTextField() {
        self.commentTextField.becomeFirstResponder()
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
