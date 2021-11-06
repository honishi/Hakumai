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

private let defaultButtonWidth = 32
private let buttonTopBottomOffset: CGFloat = 8
private let buttonRightOffset: CGFloat = 20

final class ButtonScrollView: NSScrollView {
    // MARK: - Properties
    private let topButton = NSButton()
    private let bottomButton = NSButton()
    private var isBoundsChangeObserving = false

    deinit {
        log.debug()
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.boundsDidChangeNotification,
            object: nil)
    }
}

// MARK: - Public Functions
extension ButtonScrollView {
    func enableScrollButtons() {
        enableTopScrollButton()
        enableBottomScrollButton()
    }

    func enableTopScrollButton(width: Int? = defaultButtonWidth) {
        guard topButton.target == nil else { return }

        configureButtonAppearance(topButton, image: Asset.arrowUpwardBlack.image)
        topButton.target = self
        topButton.action = #selector(topButtonPressed)
        updateTopButtonVisibility()

        // Make sure we need to call `addSubview()` of `superview`, not of `self`.
        // Seems `self` and its descendants are not controlled by auto layout,
        // and it doesn't work for this case.
        superview?.addSubview(topButton)
        topButton.snp.makeConstraints { make in
            if let width = width { make.width.equalTo(width) }
            make.right.equalTo(self).offset(-buttonRightOffset)
            make.top.equalTo(self).offset(buttonTopBottomOffset + contentView.contentInsets.top)
        }
        addBoundsDidChangeNotificationObserver()
    }

    func enableBottomScrollButton(width: Int? = defaultButtonWidth) {
        guard bottomButton.target == nil else { return }

        configureButtonAppearance(bottomButton, image: Asset.arrowDownwardBlack.image)
        bottomButton.target = self
        bottomButton.action = #selector(bottomButtonPressed)
        updateBottomButtonVisibility()

        superview?.addSubview(bottomButton)
        bottomButton.snp.makeConstraints { make in
            if let width = width { make.width.equalTo(width) }
            make.right.equalTo(self).offset(-buttonRightOffset)
            make.bottom.equalTo(self).offset(-buttonTopBottomOffset)
        }
        addBoundsDidChangeNotificationObserver()
    }

    func updateTopButtonVisibility() {
        guard topButton.target != nil else { return }
        topButton.isHidden = isReachedToTop
    }

    func updateBottomButtonVisibility() {
        guard bottomButton.target != nil else { return }
        bottomButton.isHidden = isReachedToBottom
    }
}

private extension ButtonScrollView {
    func configureButtonAppearance(_ button: NSButton, image: NSImage) {
        button.bezelStyle = .rounded
        button.image = image
        button.imageScaling = .scaleProportionallyUpOrDown
    }

    func addBoundsDidChangeNotificationObserver() {
        guard !isBoundsChangeObserving else { return }
        isBoundsChangeObserving = true
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentViewDidChangeBounds),
            name: NSView.boundsDidChangeNotification,
            object: nil)
    }

    @objc func contentViewDidChangeBounds(_ notification: Notification) {
        updateTopButtonVisibility()
        updateBottomButtonVisibility()
    }

    @objc func topButtonPressed(_ sender: Any) {
        scrollToTop()
    }

    @objc func bottomButtonPressed(_ sender: Any) {
        scrollToBottom()
    }
}
