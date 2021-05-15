//
//  CommentTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/14.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class CommentTableCellView: NSTableCellView {
    @IBOutlet private weak var commentTextField: NSTextField!

    var attributedString: NSAttributedString? {
        didSet {
            commentTextField.attributedStringValue = attributedString ?? NSAttributedString(string: "-")
        }
    }
}
