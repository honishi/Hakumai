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
    
    var userId: String? = nil {
        didSet {
            if self.userId == nil {
                self.userIdTextField.stringValue = ""
                return
            }
            
            self.userIdTextField.stringValue = self.userId!
            self.resolveAndSetLabel(self.userId!)
        }
    }
    
    // MARK: - Internal Functions
    func resolveAndSetLabel(userId: String) {
        func completion(userName: String?) {
            if userName == nil {
                return
            }
            
            self.userIdTextField.stringValue = userName!
        }
        
        NicoUtility.sharedInstance().resolveUsername(userId, completion: completion)
    }
}