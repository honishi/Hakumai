//
//  MuteViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class MuteViewController: NSViewController {
    // MARK: - Properties
    static let shared = MuteViewController.generateInstance()

    @IBOutlet var muteUserIdsArrayController: NSArrayController!
    @IBOutlet var muteWordsArrayController: NSArrayController!

    // MARK: - Object Lifecycle
    static func generateInstance() -> MuteViewController {
        return StoryboardScene.PreferenceWindowController.muteViewController.instantiate()
    }
}

extension MuteViewController {
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
}

private extension MuteViewController {
    func addMute(completion: @escaping (String) -> Void) {
        let muteAddViewController =
            StoryboardScene.PreferenceWindowController.muteAddViewController.instantiate()
        muteAddViewController.completion = { (cancelled, muteStringValue) in
            if !cancelled, let muteStringValue = muteStringValue {
                completion(muteStringValue)
            }
            self.dismiss(muteAddViewController)
            // TODO: deinit in muteAddViewController is not called after this completion
        }
        presentAsSheet(muteAddViewController)
    }
}
