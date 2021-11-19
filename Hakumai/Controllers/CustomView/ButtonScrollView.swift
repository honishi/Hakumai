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

    private var hideButtonsTimer: Timer?
    private var isMouseOnButtons = false

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
        updateButtonEnables()
        hideButtons()
        addBoundsDidChangeNotificationObserver()
    }

    func updateButtonEnables() {
        upButton.isEnabled = !isReachedToTop
        downButton.isEnabled = !isReachedToBottom
    }
}

extension ButtonScrollView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways]
        let trackingArea = NSTrackingArea(
            rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        guard !isMouseOnButtons else { return }
        showButtons(activateHideTimer: true)
    }
}

private extension ButtonScrollView {
    func showButtons(activateHideTimer: Bool) {
        hideButtonsTimer?.invalidate()
        hideButtonsTimer = nil

        upButton.isHidden = false
        downButton.isHidden = false

        guard activateHideTimer else { return }
        hideButtonsTimer = Timer.scheduledTimer(
            timeInterval: 3,
            target: self,
            selector: #selector(hideButtons),
            userInfo: nil,
            repeats: false)
    }

    @objc
    func hideButtons() {
        upButton.isHidden = true
        downButton.isHidden = true
    }
}

private extension ButtonScrollView {
    func addTopScrollButton(width: Int? = defaultButtonWidth) {
        guard upButton.superview == nil else { return }

        configureButtonAppearance(upButton, image: Asset.arrowUpwardBlack.image)
        upButton.toolTip = L10n.scrollUpButton
        upButton.onPressed = { [weak self] in self?.scrollUp() }
        upButton.onLongPressed = { [weak self] in self?.scrollToTop() }
        upButton.onMouseEntered = { [weak self] in
            self?.isMouseOnButtons = true
            self?.showButtons(activateHideTimer: false)
        }
        upButton.onMouseExited = { [weak self] in
            self?.isMouseOnButtons = false
        }

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
        downButton.onMouseEntered = { [weak self] in
            self?.isMouseOnButtons = true
            self?.showButtons(activateHideTimer: false)
        }
        downButton.onMouseExited = { [weak self] in
            self?.isMouseOnButtons = false
        }

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
        updateButtonEnables()
    }
}

// Based on https://stackoverflow.com/a/39951734/13220031
class LongPressButton: NSButton {
    var onPressed: (() -> Void)?
    var onLongPressed: (() -> Void)?
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

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
        guard isEnabled else { return }
        onPressed?()
    }
}

extension LongPressButton {
    // This custom `userInfo` dictionary is used just for indentifying whether
    // the `NSTrackingArea` instance is the one of custom mouse enter and exit tracking.
    private var _longPressButtonTrackAreaTag: [AnyHashable: Bool] {
        ["_longPressButtonMouseTrackArea": true]
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            // Remove only the `NSTrackingArea` instances of custom mouse enter
            // and exit tracking, so that `toolTip` works as expected.
            let isLongPressButtonMouseTrackArea: Bool = {
                guard let userInfo = trackingArea.userInfo as? [AnyHashable: Bool] else { return false }
                return userInfo == _longPressButtonTrackAreaTag
            }()
            guard isLongPressButtonMouseTrackArea else { continue }
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(
            rect: bounds, options: options, owner: self, userInfo: _longPressButtonTrackAreaTag)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}

private extension LongPressButton {
    @objc
    func _onLongPressed() {
        isHighlighted = false
        timer?.invalidate()
        timer = nil
        guard isEnabled else { return }
        onLongPressed?()
    }
}
