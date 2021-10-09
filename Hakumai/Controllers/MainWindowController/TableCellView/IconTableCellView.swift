//
//  IconTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/10/09.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Cocoa
import Kingfisher

enum IconType {
    case system
    case chat(URL?)
}

final class IconTableCellView: NSTableCellView {
    @IBOutlet weak var iconImageView: NSImageView!

    override func prepareForReuse() {
        iconImageView.kf.cancelDownloadTask()
        iconImageView.image = nil
    }
}

extension IconTableCellView {
    func configure(iconType: IconType) {
        switch iconType {
        case .system:
            iconImageView.image = nil
        case .chat(let iconUrl):
            if let iconUrl = iconUrl {
                iconImageView.kf.setImage(
                    with: iconUrl,
                    placeholder: Asset.defaultUserImage.image)
            } else {
                iconImageView.image = Asset.defaultUserImage.image
            }
        }
    }
}

private extension IconTableCellView {}
