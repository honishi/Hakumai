//
//  UserIdTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/2/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kImageNameUserIdHandleName = "UserIdHandleName"
private let kImageNameUserIdRawId = "UserIdRawId"
private let kImageNameUserId184Id = "UserId184Id"

class UserIdTableCellView: NSTableCellView {
    @IBOutlet weak var userIdTextField: NSTextField!
    @IBOutlet weak var userIdImageView: NSImageView!
    
    var chat: Chat? = nil {
        didSet {
            if self.chat == nil || self.chat?.userId == nil || self.chat?.premium == nil || self.chat?.comment == nil {
                self.userIdImageView.image = nil
                self.userIdTextField.stringValue = ""
                return
            }
            
            let handleName = HandleNameManager.sharedManager.handleNameForChat(self.chat!)
            
            self.userIdImageView.image = self.imageForHandleName(handleName, userId: self.chat!.userId!)
            self.setUserIdLabelWithUserId(self.chat!.userId!, premium: self.chat!.premium!, handleName: handleName)
        }
    }
    
    // MARK: - Internal Functions
    func imageForHandleName(handleName: String?, userId: String) -> NSImage {
        var image: NSImage
        
        if handleName != nil {
            image = NSImage(named: kImageNameUserIdHandleName)!
        }
        else {
            if Chat.isRawUserId(userId) {
                image = NSImage(named: kImageNameUserIdRawId)!
            }
            else {
                image = NSImage(named: kImageNameUserId184Id)!
            }
        }
        
        return image
    }
    
    func setUserIdLabelWithUserId(userId: String, premium: Premium, handleName: String?) {
        // set default name
        self.userIdTextField.stringValue = self.concatUserNameWithUserId(userId, userName: nil, handleName: handleName)
        
        // if needed, then resolve userid
        if handleName != nil || !Chat.isRawUserId(userId) || !(Chat.isUserComment(premium) || Chat.isBSPComment(premium)) {
            return
        }
        
        if let userName = NicoUtility.sharedInstance.cachedUserNameForUserId(userId) {
            self.userIdTextField.stringValue = self.concatUserNameWithUserId(userId, userName: userName, handleName: handleName)
            return
        }
        
        func completion(userName: String?) {
            if userName == nil {
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.userIdTextField.stringValue = self.concatUserNameWithUserId(userId, userName: userName, handleName: handleName)
            })
        }
        
        NicoUtility.sharedInstance.resolveUsername(userId, completion: completion)
    }
    
    func concatUserNameWithUserId(userId: String, userName: String?, handleName: String?) -> String {
        var concatenated = ""
        
        if handleName != nil {
            concatenated = handleName! + " (" + userId + ")"
        }
        else if userName != nil {
            concatenated = userName! + " (" + userId + ")"
        }
        else {
            concatenated = userId
        }
        
        return concatenated
    }
}