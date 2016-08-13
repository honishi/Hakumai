//
//  UserIdTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/2/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let kImageNameUserIdRawId = "UserIdRawId"
private let kImageNameUserId184Id = "UserId184Id"
private let kImageNameHandleNameOver184Id = "HandleNameOver184Id"
private let kImageNameHandleNameOverRawId = "HandleNameOverRawId"

class UserIdTableCellView: NSTableCellView {
    @IBOutlet weak var userIdTextField: NSTextField!
    @IBOutlet weak var userIdImageView: NSImageView!
    
    var info: (handleName: String?, userId: String?, premium: Premium?, comment: String?)? = nil {
        didSet {
            guard let userId = info?.userId, let premium = info?.premium else {
                userIdImageView.image = nil
                userIdTextField.stringValue = ""
                return
            }
            
            userIdImageView.image = imageForHandleName(info?.handleName, userId: userId)
            setUserIdLabelWithUserId(userId, premium: premium, handleName: info?.handleName)
        }
    }
    
    var fontSize: CGFloat? {
        didSet {
            setFontSize(fontSize)
        }
    }
    
    // MARK: - Internal Functions
    private func imageForHandleName(_ handleName: String?, userId: String) -> NSImage {
        var imageName: String
        
        if handleName != nil {
            imageName = Chat.isRawUserId(userId) ? kImageNameHandleNameOverRawId : kImageNameHandleNameOver184Id
        }
        else {
            imageName = Chat.isRawUserId(userId) ? kImageNameUserIdRawId : kImageNameUserId184Id
        }
        
        return NSImage(named: imageName)!
    }
    
    private func setUserIdLabelWithUserId(_ userId: String, premium: Premium, handleName: String?) {
        // set default name
        userIdTextField.stringValue = concatUserNameWithUserId(userId, userName: nil, handleName: handleName)
        
        // if needed, then resolve userid
        if handleName != nil || !Chat.isRawUserId(userId) || !(Chat.isUserComment(premium) || Chat.isBSPComment(premium)) {
            return
        }
        
        if let userName = NicoUtility.sharedInstance.cachedUserNameForUserId(userId) {
            userIdTextField.stringValue = concatUserNameWithUserId(userId, userName: userName, handleName: handleName)
            return
        }
        
        func completion(_ userName: String?) {
            if userName == nil {
                return
            }
            
            DispatchQueue.main.async {
                self.userIdTextField.stringValue = self.concatUserNameWithUserId(userId, userName: userName, handleName: handleName)
            }
        }
        
        NicoUtility.sharedInstance.resolveUsername(userId, completion: completion)
    }
    
    private func concatUserNameWithUserId(_ userId: String, userName: String?, handleName: String?) -> String {
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
    
    private func setFontSize(_ fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        userIdTextField.font = NSFont.systemFont(ofSize: size)
    }
}
