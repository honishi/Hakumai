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
            guard let premium = premium else {
                premiumImageView.image = nil
                premiumTextField.stringValue = ""
                return
            }
            
            premiumImageView.image = imageForPremium(premium)
            premiumTextField.stringValue = premium.label()
        }
    }
    
    var fontSize: CGFloat? {
        didSet {
            setFontSize(fontSize)
        }
    }
    
    // MARK: - Internal Functions
    func imageForPremium(premium: Premium) -> NSImage? {
        var image: NSImage!
        
        switch premium {
        case .Premium:
            image = NSImage(named: kImageNamePremium)!
        case .Ippan:
            image = NSImage(named: kImageNameIppan)!
        case .System, .Caster, .Operator, .BSP:
            image = NSImage(named: kImageNameMisc)!
        }
        
        return image
    }
    
    func setFontSize(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        premiumTextField.font = NSFont.systemFontOfSize(size)
    }
}