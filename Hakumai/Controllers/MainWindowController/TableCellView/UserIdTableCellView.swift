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
    var highlightQuery: String? { didSet { setUserIdLabelText(currentLabel) } }

    // XXX: remove this non presentation layer instance..
    private var nicoManager: NicoManagerType?
    private var currentUserId: String?
    private var currentLabel: String = ""
}

extension UserIdTableCellView {
    func configure(info: (nicoManager: NicoManagerType, handleName: String?, userId: String?, premium: Premium?, comment: String?)?) {
        nicoManager = info?.nicoManager
        currentUserId = info?.userId
        guard let userId = info?.userId, let premium = info?.premium else {
            userIdImageView.image = nil
            setUserIdLabelText("")
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
        setUserIdLabelText(premium.isSystem ?
                            systemUserLabel :
                            concatUserName(userId: userId, userName: nil, handleName: handleName))

        // if needed, then resolve userid
        guard handleName == nil, premium.isUser, userId.isRawUserId else { return }

        if let userName = nicoManager?.cachedUserName(for: userId) {
            setUserIdLabelText(concatUserName(userId: userId, userName: userName, handleName: handleName))
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
                me.setUserIdLabelText(
                    me.concatUserName(userId: userId, userName: userName, handleName: handleName)
                )
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
        setUserIdLabelText(currentLabel)
    }

    func setUserIdLabelText(_ text: String) {
        currentLabel = text
        userIdTextField.attributedStringValue = attributedUserIdLabel(text)
    }

    func attributedUserIdLabel(_ text: String) -> NSAttributedString {
        let size = fontSize ?? CGFloat(kDefaultFontSize)
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: size),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let query = (highlightQuery ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return attributed }

        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.length > 0 {
            let foundRange = nsText.range(
                of: query,
                options: [.caseInsensitive],
                range: searchRange
            )
            if foundRange.location == NSNotFound {
                break
            }
            attributed.addAttribute(
                .backgroundColor,
                value: UIHelper.searchMatchHighlightColor(),
                range: foundRange
            )
            let nextLocation = foundRange.location + foundRange.length
            guard nextLocation <= nsText.length else { break }
            searchRange = NSRange(
                location: nextLocation,
                length: nsText.length - nextLocation
            )
        }
        return attributed
    }
}
