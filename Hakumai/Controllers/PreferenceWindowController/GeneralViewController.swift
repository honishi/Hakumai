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

    @IBOutlet private weak var sessionManagementBox: NSBox!
    @IBOutlet private weak var sessionManagementMatrix: NSMatrix!
    @IBOutlet private weak var chromeButtonCell: NSButtonCell!
    @IBOutlet private weak var safariButtonCell: NSButtonCell!

    @IBOutlet private weak var commentSpeakingBox: NSBox!
    @IBOutlet private weak var speakCommentButton: NSButton!
    @IBOutlet private weak var speakVolumeTitleTextField: NSTextField!
    @IBOutlet private weak var speakVolumeValueTextField: NSTextField!
    @IBOutlet private weak var speakVolumeSlider: NSSlider!

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
    }

    override func viewDidAppear() {
        super.viewDidAppear()
    }
}

// MARK: - Internal Functions
private extension GeneralViewController {
    func configureView() {
        sessionManagementBox.title = L10n.sessionManagement
        chromeButtonCell.title = L10n.googleChrome
        safariButtonCell.title = L10n.safari

        commentSpeakingBox.title = L10n.commentSpeaking
        speakCommentButton.title = L10n.speakComments
        speakVolumeTitleTextField.stringValue = "\(L10n.speakVolume):"
    }

    func disableSpeakComponentsIfNeeded() {
        if #available(macOS 10.14, *) { return }
        speakCommentButton.isEnabled = false
        speakVolumeTitleTextField.isEnabled = false
        speakVolumeValueTextField.isEnabled = false
        speakVolumeSlider.isEnabled = false
    }
}
