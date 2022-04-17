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

private let leadingMargin: CGFloat = 2
private let trailingMargin: CGFloat = 2
private let giftImageViewSize = CGSize(width: 32, height: 32)
private let paddingBetweenGiftImageAndComment: CGFloat = 8

final class CommentTableCellView: NSTableCellView {
    @IBOutlet private weak var giftImageView: NSImageView!
    @IBOutlet private weak var commentTextField: NSTextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        giftImageView.enableCornerRadius(4)
    }
}

extension CommentTableCellView {
    static func calculateHeight(text: String, attributes: [NSAttributedString.Key: Any], hasGiftImage: Bool, columnWidth: CGFloat) -> CGFloat {
        let commentWidth = columnWidth
            - leadingMargin
            - trailingMargin
            - (hasGiftImage ? giftImageViewSize.width + paddingBetweenGiftImageAndComment : 0)
        let commentRect = text.boundingRect(
            with: CGSize(width: commentWidth, height: 0),
            options: .usesLineFragmentOrigin,
            attributes: attributes
        )
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")
        let giftImageHeight: CGFloat = hasGiftImage ? giftImageViewSize.height : 0
        return max(giftImageHeight, commentRect.size.height)
    }

    func configure(attributedString: NSAttributedString?, giftImageUrl: URL? = nil) {
        commentTextField.attributedStringValue = attributedString ?? NSAttributedString(string: "-")
        giftImageView.image = nil
        // XXX: set placeholder image?
        giftImageView.kf.setImage(with: giftImageUrl)
        giftImageView.isHidden = giftImageUrl == nil
    }
}
