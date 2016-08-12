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

class PremiumTableCellView: NSTableCellView {
    @IBOutlet weak var premiumImageView: NSImageView!
    @IBOutlet weak var premiumTextField: NSTextField!
    
    var premium: Premium? = nil {
        didSet {
            setPremium(premium)
        }
    }
    
    var fontSize: CGFloat? {
        didSet {
            setFontSize(fontSize)
        }
    }
    
    // MARK: - Internal Functions
    private func setPremium(_ premium: Premium?) {
        guard let premium = premium else {
            premiumImageView.image = nil
            premiumTextField.stringValue = ""
            return
        }
        
        premiumImageView.image = imageForPremium(premium)
        premiumTextField.stringValue = premium.label()
    }
    
    private func imageForPremium(_ premium: Premium) -> NSImage? {
        var image: NSImage!
        
        switch premium {
        case .premium:
            image = NSImage(named: kImageNamePremium)!
        case .ippan:
            image = NSImage(named: kImageNameIppan)!
        case .system, .caster, .operator, .bsp:
            image = NSImage(named: kImageNameMisc)!
        }
        
        return image
    }
    
    private func setFontSize(_ fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        premiumTextField.font = NSFont.systemFont(ofSize: size)
    }
}
