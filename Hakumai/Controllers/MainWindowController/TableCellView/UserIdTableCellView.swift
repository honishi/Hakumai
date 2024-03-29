//
//  UserIdTableCellView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/2/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let systemUserLabel = "----------"

final class UserIdTableCellView: NSTableCellView {
    @IBOutlet weak var userIdTextField: NSTextField!
    @IBOutlet weak var userIdImageView: NSImageView!

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }

    // XXX: remove this non presentation layer instance..
    private var nicoManager: NicoManagerType?
    private var currentUserId: String?
}

extension UserIdTableCellView {
    func configure(info: (nicoManager: NicoManagerType, handleName: String?, userId: String?, premium: Premium?, comment: String?)?) {
        nicoManager = info?.nicoManager
        currentUserId = info?.userId
        guard let userId = info?.userId, let premium = info?.premium else {
            userIdImageView.image = nil
            userIdTextField.stringValue = ""
            return
        }
        userIdImageView.image = image(forHandleName: info?.handleName, userId: userId, premium: premium)
        setUserIdLabel(userId: userId, premium: premium, handleName: info?.handleName)
    }
}

private extension UserIdTableCellView {
    func image(forHandleName handleName: String?, userId: String, premium: Premium) -> NSImage {
        if premium.isSystem {
            return Asset.premiumMisc.image
        } else if handleName != nil {
            return userId.isRawUserId ?
                Asset.handleNameOverRawId.image : Asset.handleNameOver184Id.image
        }
        return userId.isRawUserId ?
            Asset.userIdRawId.image : Asset.userId184Id.image
    }

    func setUserIdLabel(userId: String, premium: Premium, handleName: String?) {
        // set default name
        userIdTextField.stringValue = premium.isSystem ?
            systemUserLabel :
            concatUserName(userId: userId, userName: nil, handleName: handleName)

        // if needed, then resolve userid
        guard handleName == nil, premium.isUser, userId.isRawUserId else { return }

        if let userName = nicoManager?.cachedUserName(for: userId) {
            userIdTextField.stringValue = concatUserName(userId: userId, userName: userName, handleName: handleName)
            return
        }

        nicoManager?.resolveUsername(for: userId) { [weak self] in
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
