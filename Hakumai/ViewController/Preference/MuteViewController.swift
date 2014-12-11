//
//  MuteViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
private let kStoryboardNameMain = "Main"
private let kStoryboardIdMuteViewController = "MuteViewController"

class MuteViewController: NSViewController {
    // MARK: - Properties
    @IBOutlet var muteUserIdsArrayController: NSArrayController!
    
    // MARK: - Object Lifecycle
    class func generateInstance() -> MuteViewController? {
        let storyboard = NSStoryboard(name: kStoryboardNameMain, bundle: nil)
        return storyboard?.instantiateControllerWithIdentifier(kStoryboardIdMuteViewController) as? MuteViewController
    }
    
    // MARK: - dummy
    @IBAction func addDummyMuteUserId(sender: AnyObject) {
        self.muteUserIdsArrayController.addObject("123")
    }
}