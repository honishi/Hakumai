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
    struct SpeakerPopUpItem: Equatable {
        let speakerId: Int
        let name: String
    }

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
    // TODO: weak?
    @IBOutlet private var speakerPopUpButton: NSPopUpButton!

    @IBOutlet private weak var miscBox: NSBox!
    @IBOutlet private weak var enableEmotionMessageButton: NSButton!
    @IBOutlet private weak var enableLiveNotificationButton: NSButton!
    @IBOutlet private weak var enableDebugMessageButton: NSButton!

    private var speakerPopUpItems: [SpeakerPopUpItem] = []

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
        updateSpeakerPopUpButton()
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
        speakerPopUpButton.removeAllItems()
        speakerPopUpButton.isEnabled = false

        miscBox.title = L10n.misc
        enableEmotionMessageButton.title = L10n.enableEmotionMessage
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

    func updateSpeakerPopUpButton() {
        speakerPopUpButton.isEnabled = false
        VoicevoxWrapper().requestSpeakers { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let speakers):
                me.speakerPopUpItems.removeAll()
                me.speakerPopUpItems = speakers.map {
                    SpeakerPopUpItem(
                        speakerId: $0.speakerId, name: $0.name)
                }
                DispatchQueue.main.async {
                    me.configureSpeakerPopUpButton()
                }
            case .failure(let error):
                log.error(error)
            }
        }
    }

    func configureSpeakerPopUpButton() {
        speakerPopUpButton.isEnabled = true
        speakerPopUpButton.removeAllItems()
        speakerPopUpButton.addItems(withTitles: speakerPopUpItems.map({ $0.name }))

        let speakerId = UserDefaults.standard.integer(forKey: Parameters.commentSpeechVoicevoxSpeaker)
        if let selectedSpeakerPopUpItem = speakerPopUpItems.filter({ $0.speakerId == speakerId }).first,
           let indexInPopUpItems = speakerPopUpItems.firstIndex(of: selectedSpeakerPopUpItem) {
            speakerPopUpButton.selectItem(at: indexInPopUpItems)
        } else {
            speakerPopUpButton.selectItem(at: 0)
        }
    }

    @IBAction func speakerPopUpButtonChanged(_ sender: Any) {
        let indexInPopUpItems = speakerPopUpButton.indexOfSelectedItem
        let speakerId = speakerPopUpItems[indexInPopUpItems].speakerId
        UserDefaults.standard.set(speakerId, forKey: Parameters.commentSpeechVoicevoxSpeaker)
        UserDefaults.standard.synchronize()
    }
}
