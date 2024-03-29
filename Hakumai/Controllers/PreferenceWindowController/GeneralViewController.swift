//
//  GeneralViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import AVFoundation

private let sampleVoiceText = "優しく手を差し伸べてくれてる人の声に少しでも耳を傾けてほしい。傷つけようとしてる人より遥かに多いはずなのに"
private let voicevoxSiteUrl = "https://voicevox.hiroshiba.jp/"

final class GeneralViewController: NSViewController {
    struct SpeakerPopUpItem: Equatable {
        let speakerId: Int
        let name: String
    }

    // MARK: - Properties
    static let shared = GeneralViewController.make()

    @IBOutlet private weak var browserInUseBox: NSBox!
    @IBOutlet private weak var browserInUseMatrix: NSMatrix!
    @IBOutlet private weak var enableBrowserTabSelectionSyncButton: NSButton!
    @IBOutlet private weak var chromeButtonCell: NSButtonCell!
    @IBOutlet private weak var safariButtonCell: NSButtonCell!

    @IBOutlet private weak var commentSpeakingBox: NSBox!
    @IBOutlet private weak var speakVolumeTitleTextField: NSTextField!
    @IBOutlet private weak var speakVolumeValueTextField: NSTextField!
    @IBOutlet private weak var speakVolumeSlider: NSSlider!
    @IBOutlet private weak var enableSpeakNameButton: NSButton!
    @IBOutlet private weak var enableSpeakGiftButton: NSButton!
    @IBOutlet private weak var enableSpeakAdButton: NSButton!
    @IBOutlet private weak var speakerTitleTextField: NSTextField!
    @IBOutlet private weak var voicevoxSiteButton: NSButton!

    // XXX: Make the following propeties `weak`.
    // We need to refactor `PreferenceWindowController` which
    // "removeFromSuperview" all controls for every content view update..
    @IBOutlet private var speakerPopUpButton: NSPopUpButton!
    @IBOutlet private var speakSampleButton: NSButton!
    @IBOutlet private var speakSampleProgressIndicator: NSProgressIndicator!

    @IBOutlet private weak var miscBox: NSBox!
    @IBOutlet private weak var enableEmotionMessageButton: NSButton!
    @IBOutlet private weak var enableLiveNotificationButton: NSButton!
    @IBOutlet private weak var enableDebugMessageButton: NSButton!

    private var speakerPopUpItems: [SpeakerPopUpItem] = []
    private let voicevoxWrapper: VoicevoxWrapperType = VoicevoxWrapper()
    private var player: AVAudioPlayer?

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
        disableSpeakerComponents()
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
        enableBrowserTabSelectionSyncButton.title = L10n.syncBrowserTabSelection

        commentSpeakingBox.title = L10n.commentSpeaking
        speakVolumeTitleTextField.stringValue = "\(L10n.speakVolume):"
        enableSpeakNameButton.title = L10n.enableSpeakName
        enableSpeakGiftButton.title = L10n.enableSpeakGift
        enableSpeakAdButton.title = L10n.enableSpeakAd
        speakerTitleTextField.stringValue = "\(L10n.voicevoxSpeaker):"
        voicevoxSiteButton.title = L10n.voicevoxWebsite
        speakSampleButton.title = L10n.speakerSample

        miscBox.title = L10n.misc
        enableEmotionMessageButton.title = L10n.enableEmotionMessage
        enableLiveNotificationButton.title = L10n.enableLiveNotification
        enableDebugMessageButton.title = L10n.enableDebugMessage
    }

    func disableSpeakerComponents() {
        speakerPopUpButton.isEnabled = false
        speakSampleButton.isEnabled = false
        speakerPopUpButton.removeAllItems()
        speakerPopUpButton.addItems(withTitles: [L10n.voicevoxNotFound])
    }

    func updateSpeakerPopUpButton() {
        disableSpeakerComponents()
        voicevoxWrapper.requestSpeakers { [weak self] in
            guard let me = self else { return }
            switch $0 {
            case .success(let speakers):
                me.speakerPopUpItems.removeAll()
                me.speakerPopUpItems = speakers.map {
                    SpeakerPopUpItem(speakerId: $0.speakerId, name: $0.name)
                }
                DispatchQueue.main.async {
                    me.configureAndEnableSpeakerPopUpButton()
                }
            case .failure(let error):
                log.error(error)
            }
        }
    }

    func configureAndEnableSpeakerPopUpButton() {
        speakerPopUpButton.isEnabled = true
        speakSampleButton.isEnabled = true
        speakerPopUpButton.removeAllItems()
        speakerPopUpButton.addItems(withTitles: speakerPopUpItems.map({ $0.name }))

        let speakerId = speakerIdInUserDefaults()
        if let selectedSpeakerPopUpItem = speakerPopUpItems.filter({ $0.speakerId == speakerId }).first,
           let indexInPopUpItems = speakerPopUpItems.firstIndex(of: selectedSpeakerPopUpItem) {
            speakerPopUpButton.selectItem(at: indexInPopUpItems)
        }
    }

    @IBAction func speakerPopUpButtonChanged(_ sender: Any) {
        let indexInPopUpItems = speakerPopUpButton.indexOfSelectedItem
        let speakerId = speakerPopUpItems[indexInPopUpItems].speakerId
        saveSpeakerIdInUserDefaults(speakerId)
    }

    @IBAction func speakSampleButtonPressed(_ sender: Any) {
        speakSample()
    }

    @IBAction func voicevoxSiteButtonPressed(_ sender: Any) {
        guard let url = URL(string: voicevoxSiteUrl) else { return }
        NSWorkspace.shared.open(url)
    }

    func speakSample() {
        speakSampleProgressIndicator.startAnimation(self)
        speakSampleButton.isEnabled = false
        voicevoxWrapper.requestAudio(
            text: sampleVoiceText,
            speedScale: 1,
            volumeScale: Float(speechVolumeInUserDefaults()) / 100,
            speaker: speakerIdInUserDefaults()
        ) { [weak self] in
            guard let me = self else { return }
            me.speakSampleProgressIndicator.stopAnimation(me)
            me.speakSampleButton.isEnabled = true
            switch $0 {
            case .success(let data):
                guard let player = try? AVAudioPlayer(data: data) else { return }
                me.player = player
                player.play()
            case .failure(let error):
                log.error(error)
            }
        }
    }

    func speakerIdInUserDefaults() -> Int {
        return UserDefaults.standard.integer(forKey: Parameters.commentSpeechVoicevoxSpeaker)
    }

    func speechVolumeInUserDefaults() -> Int {
        return UserDefaults.standard.integer(forKey: Parameters.commentSpeechVolume)
    }

    func saveSpeakerIdInUserDefaults(_ speakerId: Int) {
        UserDefaults.standard.set(speakerId, forKey: Parameters.commentSpeechVoicevoxSpeaker)
        UserDefaults.standard.synchronize()
    }
}
