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
            guard let iconUrl = iconUrl else { return }
            let retry = DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))
            iconImageView.kf.setImage(
                with: iconUrl,
                placeholder: Asset.defaultUserImage.image,
                options: [.retryStrategy(retry)]
            )
        }
    }
}

private extension IconTableCellView {
    func reset() {
        // https://stackoverflow.com/a/62006790/13220031
        iconImageView.kf.cancelDownloadTask()
        iconImageView.kf.setImage(with: URL(string: ""))
        iconImageView.image = nil
    }
}
