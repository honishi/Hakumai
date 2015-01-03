//
//  UserIdTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/2/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

class UserIdTableCellView: NSTableCellView {
    @IBOutlet weak var userIdTextField: NSTextField!
    @IBOutlet weak var userIdImageView: NSImageView!
    
    var userId: String? = nil {
        didSet {
            if self.userId == nil {
                self.userIdImageView.image = nil
                self.userIdTextField.stringValue = ""
                return
            }
            
            self.userIdImageView.image = self.imageForUserId(self.userId!)
            self.userIdTextField.stringValue = self.userId!
            self.resolveAndSetLabel(self.userId!)
        }
    }
    
    // MARK: - Internal Functions
    func imageForUserId(userId: String) -> NSImage {
        var image: NSImage
        let isRawUserId = NicoUtility.sharedInstance.isRawUserId(userId)
        
        if isRawUserId {
            image = NSImage(named: "UserIdRaw")!
        }
        else {
            image = NSImage(named: "UserId184")!
        }
        
        return image
    }
    
    func resolveAndSetLabel(userId: String) {
        if let userName = NicoUtility.sharedInstance.cachedUsernames[userId] {
            self.userIdTextField.stringValue = userName
            return
        }
        
        func completion(userName: String?) {
            if userName == nil {
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.userIdTextField.stringValue = userName!
            })
        }
        
        NicoUtility.sharedInstance.resolveUsername(userId, completion: completion)
    }
}