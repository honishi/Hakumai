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
private let kStoryboardNamePreferenceWindowController = "PreferenceWindowController"
private let kStoryboardIdMuteViewController = "MuteViewController"
private let kStoryboardIdMuteAddViewController = "MuteAddViewController"

class MuteViewController: NSViewController {
    // MARK: - Properties
    static let sharedInstance = MuteViewController.generateInstance()
    
    @IBOutlet var muteUserIdsArrayController: NSArrayController!
    @IBOutlet var muteWordsArrayController: NSArrayController!
    
    // MARK: - Object Lifecycle
    class func generateInstance() -> MuteViewController {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        return storyboard.instantiateControllerWithIdentifier(kStoryboardIdMuteViewController) as! MuteViewController
    }
    
    // MARK: - Button Handlers
    @IBAction func addMuteUserId(sender: AnyObject) {
        self.addMute({ (muteStringValue: String) -> Void in
            self.muteUserIdsArrayController.addObject(["UserId": muteStringValue])
        })
    }
    
    @IBAction func addMuteWord(sender: AnyObject) {
        self.addMute({ (muteStringValue: String) -> Void in
            self.muteWordsArrayController.addObject(["Word": muteStringValue])
        })
    }
    
    func addMute(completion: String -> Void) {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        let muteAddViewController = storyboard.instantiateControllerWithIdentifier(kStoryboardIdMuteAddViewController) as! MuteAddViewController
        
        muteAddViewController.completion = { (cancelled: Bool, muteStringValue: String?) -> Void in
            if !cancelled {
                completion(muteStringValue!)
            }
            
            self.dismissViewController(muteAddViewController)
            // TODO: deinit in muteAddViewController is not called after this completion
        }
        
        self.presentViewControllerAsSheet(muteAddViewController)
    }
}