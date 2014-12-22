//
//  PremiumTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/7/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class PremiumTableCellView: NSTableCellView {
    @IBOutlet weak var premiumImageView: NSImageView!
    @IBOutlet weak var premiumTextField: NSTextField!
    
    var premium: Premium? = nil {
        didSet {
            if self.premium == nil {
                self.premiumImageView.image = nil
                self.premiumTextField.stringValue = ""
                return
            }
            
            self.premiumImageView.image = self.imageForPremium(self.premium!)
            self.premiumTextField.stringValue = self.premium!.label()
        }
    }
    
    // MARK: - Internal Functions
    func imageForPremium(premium: Premium) -> NSImage? {
        var image: NSImage!
        
        switch premium {
        case .Premium:
            image = NSImage(named: "Premium")!
        default:
            break
        }
        
        return image
    }
}