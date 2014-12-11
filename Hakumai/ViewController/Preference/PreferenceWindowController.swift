//
//  PreferenceWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCGLogger

// constant value for storyboard
private let kStoryboardNameMain = "Main"
private let kStoryboardIdPreferenceWindowController = "PreferenceWindowController"

private let kToolbarItemIdentifierGeneral = "GeneralToolbarItem"
private let kToolbarItemIdentifierMute = "MuteToolbarItem"

class PreferenceWindowController: NSWindowController {
    // MARK: - Properties
    @IBOutlet weak var toolbar: NSToolbar!

    let log = XCGLogger.defaultInstance()
    
    // MARK: Properties for Singleton
    class var sharedInstance : PreferenceWindowController {
        struct Static {
            static let instance : PreferenceWindowController = PreferenceWindowController.generateInstance()!
        }
        return Static.instance
    }
    
    class func generateInstance() -> PreferenceWindowController? {
        let storyboard = NSStoryboard(name: kStoryboardNameMain, bundle: nil)
        return storyboard?.instantiateControllerWithIdentifier(kStoryboardIdPreferenceWindowController) as? PreferenceWindowController
    }

    // MARK: - Object Lifecycle
    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        log.debug("")
    }
    
    // MARK: - NSObject Overrides
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // MARK: - NSWindowController Overrides
    override func windowDidLoad() {
        self.contentViewController = GeneralViewController.generateInstance()
    }
    
    // MARK: - NSToolbar Handlers
    @IBAction func changeViewController(sender: AnyObject) {
        let toolbarItem = (sender as NSToolbarItem)
        
        switch toolbarItem.itemIdentifier {
        case kToolbarItemIdentifierGeneral:
            self.contentViewController = GeneralViewController.generateInstance()
            
        case kToolbarItemIdentifierMute:
            self.contentViewController = MuteViewController.generateInstance()
            
        default:
            break
        }
        
        self.toolbar.selectedItemIdentifier = toolbarItem.itemIdentifier
    }
}