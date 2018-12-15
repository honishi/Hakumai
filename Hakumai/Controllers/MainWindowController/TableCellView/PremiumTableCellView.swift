//
//  PremiumTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/7/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kImageNamePremium = "PremiumPremium"
private let kImageNameIppan = "PremiumIppan"
private let kImageNameMisc = "PremiumMisc"

final class PremiumTableCellView: NSTableCellView {
    @IBOutlet weak var premiumImageView: NSImageView!
    @IBOutlet weak var premiumTextField: NSTextField!

    var premium: Premium? = nil { didSet { set(premium: premium) } }
    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }
}

private extension PremiumTableCellView {
    func set(premium: Premium?) {
        guard let premium = premium else {
            premiumImageView.image = nil
            premiumTextField.stringValue = ""
            return
        }
        premiumImageView.image = image(forPremium: premium)
        premiumTextField.stringValue = premium.label()
    }

    func image(forPremium premium: Premium) -> NSImage? {
        var image: NSImage?

        switch premium {
        case .premium:
            image = NSImage(named: kImageNamePremium)
        case .ippan:
            image = NSImage(named: kImageNameIppan)
        case .system, .caster, .operator, .bsp:
            image = NSImage(named: kImageNameMisc)
        }

        return image
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        premiumTextField.font = NSFont.systemFont(ofSize: size)
    }
}
