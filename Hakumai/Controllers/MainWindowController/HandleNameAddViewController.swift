//
//  HandleNameAddViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class HandleNameAddViewController: NSViewController {
    // MARK: - Properties
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private weak var cancelButton: NSButton!
    @IBOutlet private weak var setButton: NSButton!

    // this property contains handle name value, and is also used binding between text filed and add button.
    // http://stackoverflow.com/a/24017991
    // and use `dynamic` to make binding work properly. see details at the following link
    // - https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CocoaBindings/Concepts/Troubleshooting.html
    //     - Changing the value in the user interface programmatically is not reflected in the model
    //     - Changing the value of a model property programmatically is not reflected in the user interface
    // - http://stackoverflow.com/a/26564912
    // also use NSString instead of String, cause .length property is used in button's enabled binding.
    @objc dynamic var handleName: NSString = ""

    var completion: ((_ cancelled: Bool, _ handleName: String?) -> Void)?

    // MARK: - Object Lifecycle
    deinit { log.debug("") }
}

extension HandleNameAddViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }
}

// MARK: - Internal Functions
extension HandleNameAddViewController {
    @IBAction func addHandleName(_ sender: AnyObject) {
        guard 0 < handleName.length else { return }
        completion?(false, handleName as String)
    }

    @IBAction func cancelToAdd(_ sender: AnyObject) {
        completion?(true, nil)
    }
}

private extension HandleNameAddViewController {
    func configureView() {
        titleLabel.stringValue = "\(L10n.setUpdateHandleName):"
        cancelButton.title = L10n.cancel
        setButton.title = L10n.set
    }
}
