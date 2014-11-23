//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger

let kCalculateActiveInterval: NSTimeInterval = 3

var mainViewController: MainViewController?

class MainViewController: NSViewController, NicoUtilityProtocol, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var liveTextField: NSTextField!
    
    @IBOutlet weak var communityImageView: NSImageView!
    @IBOutlet weak var liveTitleLabel: NSTextField!
    @IBOutlet weak var roomPositionLabel: NSTextField!
    
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var activeLabel: NSTextField!
    @IBOutlet weak var notificationLabel: NSTextField!
    @IBOutlet weak var commentTextField: NSTextField!
    
    let log = XCGLogger.defaultInstance()

    var chats: [Chat] = []

    var activeTimer: NSTimer?
    var calculatingActive: Bool = false

    // MARK: - Object Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        mainViewController = self
    }

    class func instance() -> MainViewController? {
        return mainViewController
    }

    // MARK: - UIViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.activeTimer = NSTimer.scheduledTimerWithTimeInterval(kCalculateActiveInterval, target: self, selector: "calculateActive:", userInfo: nil, repeats: true)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // MARK: - NSTableViewDataSource Functions
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.chats.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        var content: String?
        
        if tableColumn?.identifier == "RoomPositionColumn" {
            content = self.chats[row].roomPosition?.shortLabel()
        }
        else if tableColumn?.identifier == "CommentColumn" {
            content = self.chats[row].comment
        }
        else if tableColumn?.identifier == "UserIdColumn" {
            content = self.chats[row].userId
        }
        else if tableColumn?.identifier == "PremiumColumn" {
            content = self.chats[row].premium?.label()
        }
        else if tableColumn?.identifier == "MailColumn" {
            content = self.chats[row].mail
        }
        
        if content == nil {
            content = ""
        }
        
        return content
    }
    
    // MARK: - NicoUtilityDelegate Functions
    func nicoUtilityDidExtractLive(nicoUtility: NicoUtility, live: Live) {
        dispatch_async(dispatch_get_main_queue(), {
            self.liveTitleLabel.stringValue = live.title!
        })
        
        self.loadThumbnail()
    }

    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition) {
        log.info("opened \(roomPosition.label()).")
        
        dispatch_async(dispatch_get_main_queue(), {
            // nop
        })
    }

    func nicoUtilityDidReceiveFirstChat(nicoUtility: NicoUtility, chat: Chat) {
        dispatch_async(dispatch_get_main_queue(), {
            if let roomPositionLabel = chat.roomPosition?.label() {
                self.notificationLabel.stringValue = "\(roomPositionLabel)"
            }
        })
    }

    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")

        dispatch_async(dispatch_get_main_queue(), {
            if chat.comment?.hasPrefix("/hb ifseetno ") == true {
                return
            }
            
            self.chats.append(chat)
            
            let shouldScroll = self.shouldTableViewScrollToBottom()
            
            self.tableView.reloadData()
            
            if shouldScroll {
                self.tableView.scrollRowToVisible(self.chats.count - 1)
            }
            
            self.scrollView.flashScrollers()
        })
    }

    func shouldTableViewScrollToBottom() -> Bool {
        let viewRect = self.scrollView.contentView.documentRect
        let visibleRect = self.scrollView.contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")
        
        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10
        
        return (bottomY <= (offsetBottomY + allowance))
    }
    
    func nicoUtilityDidFinishListening(nicoUtility: NicoUtility) {
        dispatch_async(dispatch_get_main_queue(), {
            self.chats.removeAll(keepCapacity: false)
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
        // TODO: should be atomic?
        // objc_sync_enter(self)
        // objc_sync_exit(self)

        if self.calculatingActive {
            log.debug("skip calcurating active")
            return
        }
        self.calculatingActive = true

        // log.debug("calcurating active")
        
        // TODO: check duplicate executes
        let qualityOfServiceClass = Int(QOS_CLASS_BACKGROUND.value)
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)

        dispatch_async(backgroundQueue, {
            var activeUsers = Dictionary<String, Bool>()
            let tenMinutesAgo = NSDate(timeIntervalSinceNow: (Double)(-10 * 60))

            // to avoid weird exc_bad_instruction(fatal error: Array index out of range) when 
            // accessing self.chats[i - 1] in for-loop, copy self.chats first
            let copiedChats = self.chats
            
            for var i = copiedChats.count; 0 < i ; i-- {
                let chat = copiedChats[i - 1]
                
                if chat.date == nil || chat.userId == nil {
                    continue
                }
                
                // is "chat.date < tenMinutesAgo" ?
                if chat.date!.compare(tenMinutesAgo) == .OrderedAscending {
                    break
                }
                
                activeUsers[chat.userId!] = true
            }

            dispatch_async(dispatch_get_main_queue(), {
                self.activeLabel.stringValue = "active: \(activeUsers.count)"
                
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
