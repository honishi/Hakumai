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
        return storyboard.instantiateController(withIdentifier: kStoryboardIdMuteViewController) as! MuteViewController
    }
    
    // MARK: - Button Handlers
    @IBAction func addMuteUserId(_ sender: AnyObject) {
        addMute { muteStringValue in
            self.muteUserIdsArrayController.addObject(["UserId": muteStringValue])
        }
    }
    
    @IBAction func addMuteWord(_ sender: AnyObject) {
        addMute { muteStringValue in
            self.muteWordsArrayController.addObject(["Word": muteStringValue])
        }
    }
    
    private func addMute(completion: @escaping (String) -> Void) {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        let muteAddViewController = storyboard.instantiateController(withIdentifier: kStoryboardIdMuteAddViewController) as! MuteAddViewController
        
        muteAddViewController.completion = { (cancelled, muteStringValue) in
            if !cancelled {
                completion(muteStringValue!)
            }
            self.dismissViewController(muteAddViewController)
            // TODO: deinit in muteAddViewController is not called after this completion
        }
        
        presentViewControllerAsSheet(muteAddViewController)
    }
}
