//
//  LiveThumbnailImageView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/10.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Cocoa
import SnapKit

private let defaultAspectRatio: CGFloat = 1

@IBDesignable
class LiveThumbnailImageView: NSImageView {
    @IBInspectable
    var height: Float = 0 { didSet { updateHeight(CGFloat(height)) } }

    override var image: NSImage? { didSet { setImage(image) } }

    private var heightConstraint: Constraint?
    private var aspectRatioConstraint: Constraint?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func awakeFromNib() {
        configure()
    }
}

private extension LiveThumbnailImageView {
    func configure() {
        updateHeight(CGFloat(height))
        updateAspectRatio(defaultAspectRatio)
    }

    func updateHeight(_ height: CGFloat) {
        heightConstraint?.deactivate()
        snp.makeConstraints { make in
            heightConstraint = make
                .height
                .equalTo(height)
                .constraint
        }
    }

    func updateAspectRatio(_ ratio: CGFloat) {
        aspectRatioConstraint?.deactivate()
        snp.makeConstraints { make in
            aspectRatioConstraint = make
                .height
                .equalTo(snp.width)
                .multipliedBy(ratio)
                .constraint
        }
    }

    func setImage(_ image: NSImage?) {
        super.image = image
        let aspectRatio: CGFloat = {
            guard let image = image else { return defaultAspectRatio }
            return image.size.height / image.size.width
        }()
        updateAspectRatio(aspectRatio)
    }
}
