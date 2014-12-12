//
//  GeneralViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
private let kStoryboardNameMain = "Main"
private let kStoryboardIdGeneralViewController = "GeneralViewController"

class GeneralViewController: NSViewController {
    // MARK: - Object Lifecycle
    class var sharedInstance : GeneralViewController {
        struct Static {
            static let instance : GeneralViewController = GeneralViewController.generateInstance()!
        }
        return Static.instance
    }

    class func generateInstance() -> GeneralViewController? {
        let storyboard = NSStoryboard(name: kStoryboardNameMain, bundle: nil)
        return storyboard?.instantiateControllerWithIdentifier(kStoryboardIdGeneralViewController) as? GeneralViewController
    }
}
