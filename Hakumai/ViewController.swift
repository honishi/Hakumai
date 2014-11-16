//
//  ViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NicoUtilityProtocol, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var liveTextField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
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
    func receiveChat(nicoUtility: NicoUtility, chat: Chat) {
        // println("\(chat.mail),\(chat.comment)")
        
        if chat.comment.hasPrefix("/hb ifseetno ") {
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
        var content = ""
        
        if tableColumn?.identifier == "RoomPositionColumn" {
            content = String(self.chats[row].roomPosition)
        }
        else if tableColumn?.identifier == "MailColumn" {
            if let mail = self.chats[row].mail {
                content = mail
            }
            else {
                content = "n/a"
            }
        }
        else if tableColumn?.identifier == "UserIdColumn" {
            content = self.chats[row].userId
        }
        else if tableColumn?.identifier == "CommentColumn" {
            content = self.chats[row].comment
        }
        
        return content
    }

    // MARK: NSTableViewDelegate Functions
    // func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
    // }
    
    @IBAction func connectLive(sender: AnyObject) {
        NicoUtility.getInstance().delegate = self
        NicoUtility.getInstance().connect(self.liveTextField.stringValue.toInt()!)
    }
    
}
