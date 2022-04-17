//
//  CommentTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/14.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import Kingfisher

private let _giftImageViewSize = CGSize(width: 32, height: 32)
private let _paddingBetweenGiftImageAndComment: CGFloat = 8

final class CommentTableCellView: NSTableCellView {
    @IBOutlet private weak var giftImageView: NSImageView!
    @IBOutlet private weak var commentTextField: NSTextField!
}

extension CommentTableCellView {
    static var giftImageViewSize: CGSize { _giftImageViewSize }
    static var paddingBetweenGiftImageAndComment: CGFloat { _paddingBetweenGiftImageAndComment }

    func configure(attributedString: NSAttributedString?, giftImageUrl: URL? = nil) {
        commentTextField.attributedStringValue = attributedString ?? NSAttributedString(string: "-")
        giftImageView.image = nil
        // TODO: set placeholder image
        giftImageView.kf.setImage(with: giftImageUrl)
        giftImageView.isHidden = giftImageUrl == nil
    }
}
