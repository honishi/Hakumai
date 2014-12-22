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
    
    // MARK: Basics
    var userId: String? {
        didSet {
            self.userIdLabel.stringValue = "UserId: " + (self.userId ?? "-")
        }
    }

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    // MARK: - [Super Class] Overrides
    // MARK: - [Protocol] Functions
    // MARK: - Public Functions
    // MARK: - Internal Functions
}
