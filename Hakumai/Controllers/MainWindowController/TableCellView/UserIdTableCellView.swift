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

final class UserIdTableCellView: NSTableCellView {
    @IBOutlet weak var userIdTextField: NSTextField!
    @IBOutlet weak var userIdImageView: NSImageView!

    var info: (handleName: String?, userId: String?, premium: Premium?, comment: String?)? = nil {
        didSet {
            self.currentUserId = info?.userId
            guard let userId = info?.userId, let premium = info?.premium else {
                userIdImageView.image = nil
                userIdTextField.stringValue = ""
                return
            }
            userIdImageView.image = image(forHandleName: info?.handleName, userId: userId)
            setUserIdLabel(userId: userId, premium: premium, handleName: info?.handleName)
        }
    }

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }

    private var currentUserId: String?
}

private extension UserIdTableCellView {
    func image(forHandleName handleName: String?, userId: String) -> NSImage {
        let imageName: String
        if handleName != nil {
            imageName = Chat.isRawUserId(userId) ? kImageNameHandleNameOverRawId : kImageNameHandleNameOver184Id
        } else {
            imageName = Chat.isRawUserId(userId) ? kImageNameUserIdRawId : kImageNameUserId184Id
        }
        guard let image = NSImage(named: imageName) else {
            log.error("fatal: this should never be happened..")
            return NSImage()
        }
        return image
    }

    func setUserIdLabel(userId: String, premium: Premium, handleName: String?) {
        // set default name
        if [.system, .caster, .operator].contains(premium) {
            userIdTextField.stringValue = "----------"
        } else {
            userIdTextField.stringValue = concatUserName(userId: userId, userName: nil, handleName: handleName)
        }

        // if needed, then resolve userid
        if handleName != nil || !Chat.isRawUserId(userId) || !(Chat.isUserComment(premium) || Chat.isBSPComment(premium)) {
            return
        }

        if let userName = NicoUtility.shared.cachedUserName(forUserId: userId) {
            userIdTextField.stringValue = concatUserName(userId: userId, userName: userName, handleName: handleName)
            return
        }

        NicoUtility.shared.resolveUsername(forUserId: userId) { [weak self] in
            guard let me = self else { return }
            guard me.currentUserId == userId else {
                // Seems the view is reused before the previous async username
                // resolving operation from this view is finished. So skip...
                log.debug("Skip updating cell user name.")
                return
            }
            guard let userName = $0 else { return }
            DispatchQueue.main.async {
                me.userIdTextField.stringValue =
                    me.concatUserName(userId: userId, userName: userName, handleName: handleName)
            }
        }
    }

    func concatUserName(userId: String, userName: String?, handleName: String?) -> String {
        let concatenated: String
        if let handleName = handleName {
            concatenated = handleName + " (" + userId + ")"
        } else if let userName = userName {
            concatenated = userName + " (" + userId + ")"
        } else {
            concatenated = userId
        }
        return concatenated
    }

    func set(fontSize: CGFloat?) {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        userIdTextField.font = NSFont.systemFont(ofSize: size)
    }
}
