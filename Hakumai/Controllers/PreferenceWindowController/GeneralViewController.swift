//
//  GeneralViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
private let kStoryboardNamePreferenceWindowController = "PreferenceWindowController"
private let kStoryboardIdGeneralViewController = "GeneralViewController"

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
    static let shared = GeneralViewController.generateInstance()

    @IBOutlet weak var sessionManagementMatrix: NSMatrix!
    @IBOutlet weak var mailAddressTextField: NSTextField!
    @IBOutlet weak var checkAccountButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var checkAccountStatusLabel: NSTextField!

    @IBOutlet weak var speakCommentButton: NSButton!
    @IBOutlet weak var speakVolumeTextField: NSTextField!
    @IBOutlet weak var speakVolumeValueTextField: NSTextField!
    @IBOutlet weak var speakVolumeSlider: NSSlider!

    @objc dynamic var mailAddress: NSString! {
        didSet {
            validateCheckAccountButton()
        }
    }
    @objc dynamic var password: NSString! {
        didSet {
            validateCheckAccountButton()
        }
    }

    // MARK: - Object Lifecycle
    static func generateInstance() -> GeneralViewController? {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        return storyboard.instantiateController(withIdentifier: kStoryboardIdGeneralViewController) as? GeneralViewController
    }
}

// MARK: - NSViewController Overrides
extension GeneralViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
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

extension GeneralViewController {
    @IBAction func detectedChangeInSessionManagementMatrix(_ sender: AnyObject) {
        guard let matrix = sender as? NSMatrix else { return }
        // log.debug("\(matrix.selectedTag())")
        if matrix.selectedTag() == SessionManagementType.login.rawValue {
            mailAddressTextField.becomeFirstResponder()
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
                    self.checkAccountStatusLabel.stringValue = "Status: Failed"
                    return
                }
                self.checkAccountStatusLabel.stringValue = "Status: Success"
                KeychainUtility.removeAllAccountsInKeychain()
                KeychainUtility.setAccountToKeychain(mailAddress: self.mailAddress as String, password: self.password as String)
            }
        }
        progressIndicator.startAnimation(self)
        CookieUtility.requestLoginCookie(mailAddress: mailAddress as String, password: password as String, completion: completion)
    }
}

// MARK: - Internal Functions
private extension GeneralViewController {
    func disableSpeakComponentsIfNeeded() {
        if #available(macOS 10.14, *) { return }
        speakCommentButton.isEnabled = false
        speakVolumeTextField.isEnabled = false
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
