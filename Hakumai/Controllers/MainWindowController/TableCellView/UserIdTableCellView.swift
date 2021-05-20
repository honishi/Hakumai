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

    var info: (handleName: String?, userId: String?, premium: Premium?, comment: String?)? = nil {
        didSet {
            self.currentUserId = info?.userId
            guard let userId = info?.userId, let premium = info?.premium else {
                userIdImageView.image = nil
                userIdTextField.stringValue = ""
                return
            }
            userIdImageView.image = image(forHandleName: info?.handleName, userId: userId, premium: premium)
            setUserIdLabel(userId: userId, premium: premium, handleName: info?.handleName)
        }
    }

    var fontSize: CGFloat? { didSet { set(fontSize: fontSize) } }

    private var currentUserId: String?
    private let userNameResolvingOperationQueue = OperationQueue()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
}

private extension UserIdTableCellView {
    func configure() {
        userNameResolvingOperationQueue.maxConcurrentOperationCount = 1
    }

    func image(forHandleName handleName: String?, userId: String, premium: Premium) -> NSImage {
        if premium.isSystem {
            return Asset.premiumMisc.image
        } else if handleName != nil {
            return Chat.isRawUserId(userId) ?
                Asset.handleNameOverRawId.image : Asset.handleNameOver184Id.image
        }
        return Chat.isRawUserId(userId) ?
            Asset.userIdRawId.image : Asset.userId184Id.image
    }

    func setUserIdLabel(userId: String, premium: Premium, handleName: String?) {
        // set default name
        userIdTextField.stringValue = premium.isSystem ?
            systemUserLabel :
            concatUserName(userId: userId, userName: nil, handleName: handleName)

        // if needed, then resolve userid
        if handleName != nil || !Chat.isRawUserId(userId) || !Chat.isUserComment(premium) {
            return
        }

        if let userName = NicoUtility.shared.cachedUserName(forUserId: userId) {
            updateUserIdTextField(userId: userId, userName: userName, handleName: handleName)
            return
        }

        userNameResolvingOperationQueue.cancelAllOperations()
        userNameResolvingOperationQueue.addOperation { [weak self] in
            guard let me = self else { return }

            // 1. Again, chech if the user name is resolved before this operation starts.
            if let userName = NicoUtility.shared.cachedUserName(forUserId: userId) {
                me.updateUserIdTextField(userId: userId, userName: userName, handleName: handleName)
                log.debug("Use cached username resolved in other operation.")
                return
            }

            // 2. Ok, there's no cached one, request nickname api synchronously using semaphore, NOT async.
            // https://github.com/Alamofire/Alamofire/issues/1147#issuecomment-212791012
            // https://qiita.com/shtnkgm/items/d552bd3cf709266a9050#dispatchsemaphore%E3%82%92%E5%88%A9%E7%94%A8%E3%81%97%E3%81%A6%E9%9D%9E%E5%90%8C%E6%9C%9F%E5%87%A6%E7%90%86%E3%81%AE%E5%AE%8C%E4%BA%86%E3%82%92%E5%BE%85%E3%81%A4
            let semaphore = DispatchSemaphore(value: 0)
            NicoUtility.shared.resolveUsername(forUserId: userId) {
                defer { semaphore.signal() }
                guard me.currentUserId == userId else {
                    // Seems the view is reused before the previous async username
                    // resolving operation from this view is finished. So skip...
                    log.debug("Skip updating cell user name.")
                    return
                }
                guard let userName = $0 else { return }
                me.updateUserIdTextField(userId: userId, userName: userName, handleName: handleName)
            }
            semaphore.wait()
        }
    }

    func updateUserIdTextField(userId: String, userName: String?, handleName: String?) {
        DispatchQueue.main.async {
            self.userIdTextField.stringValue =
                self.concatUserName(userId: userId, userName: userName, handleName: handleName)
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
