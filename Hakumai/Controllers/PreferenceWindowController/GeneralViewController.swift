//
//  GeneralViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class GeneralViewController: NSViewController {
    // MARK: - Properties
    static let shared = GeneralViewController.make()

    @IBOutlet private weak var browserInUseBox: NSBox!
    @IBOutlet private weak var browserInUseMatrix: NSMatrix!
    @IBOutlet private weak var chromeButtonCell: NSButtonCell!
    @IBOutlet private weak var safariButtonCell: NSButtonCell!

    @IBOutlet private weak var commentSpeakingBox: NSBox!
    @IBOutlet private weak var speakVolumeTitleTextField: NSTextField!
    @IBOutlet private weak var speakVolumeValueTextField: NSTextField!
    @IBOutlet private weak var speakVolumeSlider: NSSlider!

    @IBOutlet private weak var miscBox: NSBox!
    @IBOutlet private weak var enableLiveNotificationButton: NSButton!
    @IBOutlet private weak var enableDebugMessageButton: NSButton!

    // MARK: - Object Lifecycle
    static func make() -> GeneralViewController {
        return StoryboardScene.PreferenceWindowController.generalViewController.instantiate()
    }
}

// MARK: - NSViewController Overrides
extension GeneralViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        disableSpeakComponentsIfNeeded()
        disableNotificationComponentsIfNeeded()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
    }
}

// MARK: - Internal Functions
private extension GeneralViewController {
    func configureView() {
        browserInUseBox.title = L10n.browserInUse
        chromeButtonCell.title = L10n.googleChrome
        safariButtonCell.title = L10n.safari

        commentSpeakingBox.title = L10n.commentSpeaking
        speakVolumeTitleTextField.stringValue = "\(L10n.speakVolume):"

        miscBox.title = L10n.misc
        enableLiveNotificationButton.title = L10n.enableLiveNotification
        enableDebugMessageButton.title = L10n.enableDebugMessage
    }

    func disableSpeakComponentsIfNeeded() {
        if #available(macOS 10.14, *) { return }
        speakVolumeTitleTextField.isEnabled = false
        speakVolumeValueTextField.isEnabled = false
        speakVolumeSlider.isEnabled = false
    }

    func disableNotificationComponentsIfNeeded() {
        if #available(macOS 10.14, *) { return }
        enableLiveNotificationButton.isHidden = true
    }
}
