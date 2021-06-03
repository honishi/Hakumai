//
//  L10n+Extensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/06/03.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa

private let fatalErrorMessageForGetter = "only set this value"

extension NSMenu {
    @IBInspectable
    private var localizedKey: String? {
        get { fatalError(fatalErrorMessageForGetter) }
        set { title = newValue?.localized ?? "" }
    }
}

extension NSMenuItem {
    @IBInspectable
    private var localizedKey: String? {
        get { fatalError(fatalErrorMessageForGetter) }
        set { title = newValue?.localized ?? "" }
    }
}

extension NSTextField {
    @IBInspectable
    private var localizedKey: String? {
        get { fatalError(fatalErrorMessageForGetter) }
        set { stringValue = newValue?.localized ?? "" }
    }
}

extension String {
    var localized: String? { NSLocalizedString(self, comment: "") }
}
