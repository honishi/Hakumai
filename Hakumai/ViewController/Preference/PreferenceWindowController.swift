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
let kStoryboardNameMain = "Main"
let kPreferenceWindowControllerStoryboardId = "PreferenceWindowController"

class PreferenceWindowController: NSWindowController {
    // MARK: - Properties
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
        return storyboard?.instantiateControllerWithIdentifier(kPreferenceWindowControllerStoryboardId) as? PreferenceWindowController
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
}