//
//  GeneralViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

private let defaultAccountStatusValue = "---"

// - @objc() is required http://stackoverflow.com/a/27178765
// - sample that returns bool http://stackoverflow.com/a/8327909
@objc(IsLoginSessionManagementTransformer) class IsLoginSessionManagementTransformer: ValueTransformer {
    override static func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return (value as? Int) == SessionManagementType.login.rawValue ? NSNumber(value: true) : NSNumber(value: false)
    }
}

final class GeneralViewController: NSViewController {
    // MARK: - Properties
    static let shared = GeneralViewController.make()

    @IBOutlet private weak var sessionManagementBox: NSBox!
    @IBOutlet private weak var sessionManagementMatrix: NSMatrix!
    @IBOutlet private weak var chromeButtonCell: NSButtonCell!
    @IBOutlet private weak var safariButtonCell: NSButtonCell!
    @IBOutlet private weak var loginButtonCell: NSButtonCell!
    @IBOutlet private weak var mailAddressTitleTextField: NSTextField!
    @IBOutlet private weak var mailAddressValueTextField: NSTextField!
    @IBOutlet private weak var passwordTitleTextField: NSTextField!
    @IBOutlet private weak var checkAccountButton: NSButton!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!
    @IBOutlet private weak var checkAccountStatusTitleLabel: NSTextField!
    @IBOutlet private weak var checkAccountStatusValueLabel: NSTextField!

    @IBOutlet private weak var commentSpeakingBox: NSBox!
    @IBOutlet private weak var speakCommentButton: NSButton!
    @IBOutlet private weak var speakVolumeTitleTextField: NSTextField!
    @IBOutlet private weak var speakVolumeValueTextField: NSTextField!
    @IBOutlet private weak var speakVolumeSlider: NSSlider!

    @objc dynamic var mailAddress: NSString! { didSet { validateCheckAccountButton() } }
    @objc dynamic var password: NSString! { didSet { validateCheckAccountButton() } }

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

        if let account = KeychainUtility.accountInKeychain() {
            mailAddress = account.mailAddress as NSString
            password = account.password as NSString
        }
        validateCheckAccountButton()
    }
}

// TODO: remove
extension GeneralViewController {
    @IBAction func detectedChangeInSessionManagementMatrix(_ sender: AnyObject) {
        guard let matrix = sender as? NSMatrix else { return }
        // log.debug("\(matrix.selectedTag())")
        if matrix.selectedTag() == SessionManagementType.login.rawValue {
            mailAddressValueTextField.becomeFirstResponder()
        }
    }

    @IBAction func detectedEnterInTextField(_ sender: AnyObject) {
        guard canLogin() else { return }
        checkAccount(self)
    }

    @IBAction func checkAccount(_ sender: AnyObject) {
        log.debug("login w/ [\(String(describing: self.mailAddress))][\(String(describing: self.password))]")
        guard canLogin() else { return }
        let completion = { (userSessionCookie: String?) -> Void in
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(self)
                if userSessionCookie == nil {
                    self.checkAccountStatusValueLabel.stringValue = L10n.failed
                    return
                }
                self.checkAccountStatusValueLabel.stringValue = L10n.success
                KeychainUtility.removeAllAccountsInKeychain()
                KeychainUtility.setAccountToKeychain(mailAddress: self.mailAddress as String, password: self.password as String)
            }
        }
        progressIndicator.startAnimation(self)
        // CookieUtility.requestLoginCookie(mailAddress: mailAddress as String, password: password as String, completion: completion)
    }
}

// MARK: - Internal Functions
private extension GeneralViewController {
    func configureView() {
        sessionManagementBox.title = L10n.sessionManagement
        chromeButtonCell.title = L10n.googleChrome
        safariButtonCell.title = L10n.safari
        loginButtonCell.title = L10n.directLogin
        mailAddressTitleTextField.stringValue = "\(L10n.mailAddress):"
        passwordTitleTextField.stringValue = "\(L10n.password):"
        checkAccountButton.title = L10n.check
        checkAccountStatusTitleLabel.stringValue = "\(L10n.status):"
        checkAccountStatusValueLabel.stringValue = defaultAccountStatusValue

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

    func validateCheckAccountButton() {
        checkAccountButton?.isEnabled = canLogin()
    }

    func canLogin() -> Bool {
        guard mailAddress != nil, password != nil else { return false }
        let loginSelected = sessionManagementMatrix?.selectedTag() == SessionManagementType.login.rawValue
        let hasValidMailAddress = (mailAddress as String).hasRegexp(pattern: kRegexpMailAddress)
        let hasValidPassword = (password as String).hasRegexp(pattern: kRegexpPassword)
        return loginSelected && hasValidMailAddress && hasValidPassword
    }
}
