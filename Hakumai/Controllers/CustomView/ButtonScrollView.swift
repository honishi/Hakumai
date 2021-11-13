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
private let buttonTopBottomMargin: CGFloat = 8
private let buttonRightMargin: CGFloat = 20
private let longPressInterval: TimeInterval = 0.5

final class ButtonScrollView: NSScrollView {
    // MARK: - Properties
    private let upButton = LongPressButton()
    private let downButton = LongPressButton()
    private var isBoundsChangeObserving = false

    deinit {
        log.debug()
        removeBoundsDidChangeNotificationObserver()
    }
}

// MARK: - Public Functions
extension ButtonScrollView {
    func enableScrollButtons() {
        addTopScrollButton()
        addBottomScrollButton()
        updateButtonVisibilities()
        addBoundsDidChangeNotificationObserver()
    }

    func updateButtonVisibilities() {
        upButton.isHidden = isReachedToTop
        downButton.isHidden = isReachedToBottom
    }
}

private extension ButtonScrollView {
    func addTopScrollButton(width: Int? = defaultButtonWidth) {
        guard upButton.superview == nil else { return }

        configureButtonAppearance(upButton, image: Asset.arrowUpwardBlack.image)
        upButton.toolTip = L10n.scrollUpButton
        upButton.onPressed = { [weak self] in self?.scrollUp() }
        upButton.onLongPressed = { [weak self] in self?.scrollToTop() }

        // Make sure we need to call `addSubview()` of `superview`, not of `self`.
        // Seems `self` and its descendants are not controlled by auto layout,
        // and it doesn't work for this case.
        superview?.addSubview(upButton)
        upButton.snp.makeConstraints { make in
            if let width = width { make.width.equalTo(width) }
            make.right.equalTo(self).offset(-buttonRightMargin)
            make.top.equalTo(self).offset(buttonTopBottomMargin + contentView.contentInsets.top)
        }
    }

    func addBottomScrollButton(width: Int? = defaultButtonWidth) {
        guard downButton.superview == nil else { return }

        configureButtonAppearance(downButton, image: Asset.arrowDownwardBlack.image)
        downButton.toolTip = L10n.scrollDownButton
        downButton.onPressed = { [weak self] in self?.scrollDown() }
        downButton.onLongPressed = { [weak self] in self?.scrollToBottom() }

        superview?.addSubview(downButton)
        downButton.snp.makeConstraints { make in
            if let width = width { make.width.equalTo(width) }
            make.right.equalTo(self).offset(-buttonRightMargin)
            make.bottom.equalTo(self).offset(-buttonTopBottomMargin)
        }
    }

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

    func removeBoundsDidChangeNotificationObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.boundsDidChangeNotification,
            object: nil)
    }

    @objc func contentViewDidChangeBounds(_ notification: Notification) {
        updateButtonVisibilities()
    }
}

// Based on https://stackoverflow.com/a/39951734/13220031
class LongPressButton: NSButton {
    var onPressed: (() -> Void)?
    var onLongPressed: (() -> Void)?

    private var timer: Timer?

    deinit { log.debug() }

    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
        timer = Timer.scheduledTimer(
            timeInterval: longPressInterval,
            target: self,
            selector: #selector(_onLongPressed),
            userInfo: nil,
            repeats: false)
    }

    override func mouseUp(with event: NSEvent) {
        isHighlighted = false
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        onPressed?()
    }
}

private extension LongPressButton {
    @objc
    func _onLongPressed() {
        isHighlighted = false
        timer?.invalidate()
        timer = nil
        onLongPressed?()
    }
}
