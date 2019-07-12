//
//  MuteAddViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/28/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class MuteAddViewController: NSViewController {
    // MARK: - Properties
    // this property contains mute target value, and is also used binding between text filed and add button.
    // http://stackoverflow.com/a/24017991
    // also see more detailed note in HandleNameAddViewController's propery
    @objc dynamic var muteValue: NSString!

    var completion: ((_ cancelled: Bool, _ muteValue: String?) -> Void)?

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        log.debug("")
    }
}

// MARK: - Internal Functions
extension MuteAddViewController {
    // MARK: Button Handlers
    @IBAction func addMute(_ sender: AnyObject) {
        guard 0 < muteValue.length else { return }
        completion?(false, muteValue as String)
    }

    @IBAction func cancelAddMute(_ sender: AnyObject) {
        completion?(true, nil)
    }
}
