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
            
            if let userId = userId {
                userIdLabelValue = userId
                
                if let userName = NicoUtility.sharedInstance.cachedUserName(forUserId: userId) {
                    userNameLabelValue = userName
                }
                
                messages = MessageContainer.sharedContainer.messagesWithUserId(userId)
            }
            else {
                messages.removeAll(keepingCapacity: false)
                rowHeightCacher.removeAll(keepingCapacity: false)
            }
            
            userIdLabel.stringValue = "UserId: " + (userIdLabelValue ?? "-----")
            userNameLabel.stringValue = "UserName: " + (userNameLabelValue ?? "-----")
            
            reloadMessages()
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
        
        registerNibs()
    }
    
    private func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameScoreTableCellView, kScoreColumnIdentifier)]
        
        for (nibName, identifier) in nibs {
            let nib = NSNib(nibNamed: nibName, bundle: Bundle.main)
            tableView.register(nib!, forIdentifier: identifier)
        }
    }
    
    // MARK: - NSTableViewDataSource Functions
    func numberOfRowsInTableView(_ tableView: NSTableView) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = messages[row]
        
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
        
        let (content, attributes) = contentAndAttributes(forMessage: message)
        
        let commentRect = content.boundingRect(with: CGSize(width: width - widthPadding, height: 0),
            options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: attributes)
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")
        
        return commentRect.size.height
    }
    
    func tableViewColumnDidResize(_ aNotification: Notification) {
        let column = (aNotification as NSNotification).userInfo?["NSTableColumn"] as! NSTableColumn
        
        if column.identifier == kCommentColumnIdentifier {
            rowHeightCacher.removeAll(keepingCapacity: false)
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var view: NSTableCellView?
        
        if let identifier = tableColumn?.identifier {
            view = tableView.make(withIdentifier: identifier, owner: self) as? NSTableCellView
            view?.textField?.stringValue = ""
        }
        
        let message = messages[row]
        
        if message.messageType == .chat {
            configureView(forChat: message, tableColumn: tableColumn!, view: view!)
        }
        
        return view
    }
    
    private func configureView(forChat message: Message, tableColumn: NSTableColumn, view: NSTableCellView) {
        let chat = message.chat!
        
        var attributed: NSAttributedString?
        
        switch tableColumn.identifier {
        case kRoomPositionColumnIdentifier:
            let roomPositionView = (view as! RoomPositionTableCellView)
            roomPositionView.roomPosition = chat.roomPosition!
            roomPositionView.commentNo = chat.no!
        case kScoreColumnIdentifier:
            (view as! ScoreTableCellView).chat = chat
        case kCommentColumnIdentifier:
            let (content, attributes) = contentAndAttributes(forMessage: message)
            attributed = NSAttributedString(string: content as String, attributes: attributes)
        default:
            break
        }
        
        if attributed != nil {
            view.textField?.attributedStringValue = attributed!
        }
    }
    
    // MARK: Utility
    private func contentAndAttributes(forMessage message: Message) -> (NSString, [String: AnyObject]) {
        var content: NSString!
        var attributes: [String: AnyObject]!
        
        if message.messageType == .system {
            content = message.message!
            attributes = UIHelper.normalCommentAttributes()
        }
        else if message.messageType == .chat {
            content = message.chat!.comment!
            attributes = (message.firstChat == true ? UIHelper.boldCommentAttributes() : UIHelper.normalCommentAttributes())
        }
        
        return (content, attributes)
    }
    
    private func shouldTableViewScrollToBottom() -> Bool {
        let viewRect = scrollView.contentView.documentRect
        let visibleRect = scrollView.contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")
        
        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10
        
        let shouldScroll = (bottomY <= (offsetBottomY + allowance))
        
        return shouldScroll
    }
    
    private func scrollTableViewToBottom() {
        let clipView = scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        let origin = NSMakePoint(x, y)
        
        clipView.setBoundsOrigin(origin)
    }
    
    // MARK: - Public Functions
    
    // MARK: - Internal Functions
    private func reloadMessages() {
        let shouldScroll = shouldTableViewScrollToBottom()
        
        tableView.reloadData()
        
        if shouldScroll {
            scrollTableViewToBottom()
        }
        
        scrollView.flashScrollers()
    }
}
