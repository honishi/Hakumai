//
//  MainViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCGLogger


class MainViewController: NSViewController, NicoUtilityProtocol, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var liveTextField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
    let log = XCGLogger.defaultInstance()
    
    var chats: [Chat] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // CookieUtility.chromeCookie()
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    // MARK: NicoUtilityDelegate Functions
    func nicoUtilityDidStartListening(nicoUtility: NicoUtility, roomPosition: RoomPosition) {
        log.info("opened \(roomPosition.label()).")
    }

    func nicoUtilityDidReceiveChat(nicoUtility: NicoUtility, chat: Chat) {
        // log.debug("\(chat.mail),\(chat.comment)")
        
        if chat.comment?.hasPrefix("/hb ifseetno ") == true {
            return
        }
        
        self.chats.append(chat)
        
        self.tableView.reloadData()
        self.tableView.scrollRowToVisible(self.chats.count - 1)
    }
    
    // MARK: NSTableViewDataSource Functions
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.chats.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        var content: String?
        
        if tableColumn?.identifier == "RoomPositionColumn" {
            content = self.chats[row].roomPosition?.shortLabel()
        }
        else if tableColumn?.identifier == "MailColumn" {
            content = self.chats[row].mail
        }
        else if tableColumn?.identifier == "UserIdColumn" {
            content = self.chats[row].userId
        }
        else if tableColumn?.identifier == "CommentColumn" {
            content = self.chats[row].comment
        }
        
        if content == nil {
            content = ""
        }
        
        return content
    }

    // MARK: NSTableViewDelegate Functions
    // func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
    // }
    
    // MARK: - Button Handlers
    @IBAction func connectLive(sender: AnyObject) {
        if let liveNumber = MainViewController.extractLiveNumber(self.liveTextField.stringValue) {
            NicoUtility.getInstance().delegate = self
            NicoUtility.getInstance().connect(liveNumber)
        }
    }
    
    @IBAction func addRoom(sender: AnyObject) {
        NicoUtility.getInstance().addMessageServer()
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
