//
//  UserViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
/*
private let kStoryboardIdGeneralViewController = "GeneralViewController"
 */

class UserViewController: NSViewController {
    // MARK: - Properties
    // MARK: Outlets
    @IBOutlet weak var userIdLabel: NSTextField!
    @IBOutlet weak var userNameLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    // MARK: Basics
    var userId: String? {
        didSet {
            var userIdLabelValue: String?
            var userNameLabelValue: String?
            
            if let userId = self.userId {
                userIdLabelValue = userId
                
                if let userName = NicoUtility.sharedInstance.cachedUserNameForUserId(userId) {
                    userNameLabelValue = userName
                }
                
                self.messages = MessageContainer.sharedContainer.messagesWithUserId(userId)
            }
            else {
                self.messages.removeAll(keepCapacity: false)
                self.rowHeightCacher.removeAll(keepCapacity: false)
            }
            
            self.userIdLabel.stringValue = "UserId: " + (userIdLabelValue ?? "-----")
            self.userNameLabel.stringValue = "UserName: " + (userNameLabelValue ?? "-----")
            
            self.reloadMessages()
        }
    }
    var messages = [Message]()

    var rowHeightCacher = [Int: CGFloat]()

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - NSViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.registerNibs()
    }
    
    func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameScoreTableCellView, kScoreColumnIdentifier)]
        
        for (nibName, identifier) in nibs {
            let nib = NSNib(nibNamed: nibName, bundle: NSBundle.mainBundle())
            self.tableView.registerNib(nib!, forIdentifier: identifier)
        }
    }
    
    // MARK: - NSTableViewDataSource Functions
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.messages.count
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = self.messages[row]
        
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
        
        return commentRect.size.height
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
        
        let message = self.messages[row]
        
        if message.messageType == .Chat {
            self.configureViewForChat(message, tableColumn: tableColumn!, view: view!)
        }
        
        return view
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
    
    func shouldTableViewScrollToBottom() -> Bool {
        let viewRect = self.scrollView.contentView.documentRect
        let visibleRect = self.scrollView.contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")
        
        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10
        
        let shouldScroll = (bottomY <= (offsetBottomY + allowance))
        
        return shouldScroll
    }
    
    func scrollTableViewToBottom() {
        let clipView = self.scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        let origin = NSMakePoint(x, y)
        
        clipView.setBoundsOrigin(origin)
    }
    
    // MARK: - Public Functions
    
    // MARK: - Internal Functions
    func reloadMessages() {
        let shouldScroll = self.shouldTableViewScrollToBottom()
        
        self.tableView.reloadData()
        
        if shouldScroll {
            self.scrollTableViewToBottom()
        }
        
        self.scrollView.flashScrollers()
    }
}
