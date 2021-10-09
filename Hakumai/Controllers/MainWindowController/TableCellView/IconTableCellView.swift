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
    case none
    case user(URL?)
}

final class IconTableCellView: NSTableCellView {
    @IBOutlet weak var iconImageView: NSImageView!

    override func prepareForReuse() {}
}

extension IconTableCellView {
    func configure(iconType: IconType) {
        reset()
        switch iconType {
        case .none:
            // no-op.
            break
        case .user(let iconUrl):
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

private extension IconTableCellView {
    func reset() {
        iconImageView.kf.cancelDownloadTask()
        iconImageView.image = nil
    }
}
