//
//  BottomButtonScrollView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/30.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Cocoa
import SnapKit

final class BottomButtonScrollView: NSScrollView {
    // MARK: - Properties
    private let bottomButton = NSButton()
}

// MARK: - Public Functions
extension BottomButtonScrollView {
    func enableBottomScrollButton(title: String = "👇", width: Int? = 80) {
        guard bottomButton.target == nil else { return }

        bottomButton.bezelStyle = .rounded
        bottomButton.title = title
        bottomButton.target = self
        bottomButton.action = #selector(bottomScrollButtonPressed)
        bottomButton.isHidden = true

        // Make sure we need to call `addSubview()` of `superview`, not of `self`.
        // Seems `self` and its descendants are not controlled by auto layout,
        // and it doesn't work for this case.
        superview?.addSubview(bottomButton)
        bottomButton.snp.makeConstraints { make in
            if let width = width { make.width.equalTo(width) }
            make.centerX.equalTo(self)
            make.bottom.equalTo(self).offset(-8)
        }

        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentViewDidChangeBounds),
            name: NSView.boundsDidChangeNotification,
            object: nil)
    }

    @objc func contentViewDidChangeBounds(_ notification: Notification) {
        bottomButton.isHidden = isReachedToBottom
    }

    @objc func bottomScrollButtonPressed(_ sender: Any) {
        scrollToBottom()
    }
}
