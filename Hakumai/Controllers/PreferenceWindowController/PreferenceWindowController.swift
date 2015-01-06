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
private let kStoryboardNamePreferenceWindowController = "PreferenceWindowController"
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
            static let instance : PreferenceWindowController = PreferenceWindowController.generateInstance()
        }
        return Static.instance
    }
    
    class func generateInstance() -> PreferenceWindowController {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)!
        let preferenceWindowController = storyboard.instantiateControllerWithIdentifier(kStoryboardIdPreferenceWindowController) as PreferenceWindowController
        
        preferenceWindowController.window?.center()
        
        return preferenceWindowController
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
        self.changeContent(GeneralViewController.sharedInstance, itemIdentifier: kToolbarItemIdentifierGeneral)
        
        self.window?.center()
        self.window?.makeKeyWindow()
    }
    
    // MARK: - NSToolbar Handlers
    @IBAction func changeViewController(sender: AnyObject) {
        let toolbarItem = (sender as NSToolbarItem)
        var viewController: NSViewController?
        
        switch toolbarItem.itemIdentifier {
        case kToolbarItemIdentifierGeneral:
            viewController = GeneralViewController.sharedInstance
            
        case kToolbarItemIdentifierMute:
            viewController = MuteViewController.sharedInstance
            
        default:
            break
        }
        
        if viewController != nil {
            self.changeContent(viewController!, itemIdentifier: toolbarItem.itemIdentifier)
        }
    }

    // MARK: - Internal Functions
    
    // MARK: Content View Utility
    // based on this implementation;
    // https://github.com/sequelpro/sequelpro/blob/fd3ff51dc624be5ce645ce25eb72d03e5a359416/Source/SPPreferenceController.m#L248
    func changeContent(viewController: NSViewController, itemIdentifier: String) {
        if let subViews = self.window?.contentView.subviews {
            for subView in subViews {
                subView.removeFromSuperview()
            }
        }
        
        self.window?.contentView.addSubview(viewController.view)
        self.resizeWindowForContentView(viewController.view)
        
        self.toolbar.selectedItemIdentifier = itemIdentifier
    }
    
    func resizeWindowForContentView(view: NSView) {
        let viewSize = view.frame.size
        var frame = self.window!.frame

        let titleHeight: CGFloat = 22
        var resizedHeight = viewSize.height + titleHeight + self.toolbarHeight()
        
        frame.origin.y += frame.size.height - resizedHeight
        frame.size.height = resizedHeight
        frame.size.width = viewSize.width
        
        self.window?.setFrame(frame, display: true, animate: true)
    }

    func toolbarHeight() -> CGFloat {
        var toolbarHeight: CGFloat = 0
        
        if self.toolbar != nil && self.toolbar.visible {
            let windowFrame = NSWindow.contentRectForFrameRect(self.window!.frame, styleMask: self.window!.styleMask)
            toolbarHeight = NSHeight(windowFrame) - NSHeight(self.window!.contentView.frame)
        }
        
        return toolbarHeight
    }
}