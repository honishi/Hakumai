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
        return (value as! Int) == SessionManagementType.login.rawValue ? NSNumber(value: true) : NSNumber(value: false)
    }
}

class GeneralViewController: NSViewController {
    // MARK: - Properties
    static let shared = GeneralViewController.generateInstance()

    @IBOutlet weak var sessionManagementMatrix: NSMatrix!
    @IBOutlet weak var mailAddressTextField: NSTextField!
    @IBOutlet weak var checkAccountButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var checkAccountStatusLabel: NSTextField!
    
    dynamic var mailAddress: NSString! {
        didSet {
            validateCheckAccountButton()
        }
    }
    dynamic var password: NSString! {
        didSet {
            validateCheckAccountButton()
        }
    }
    
    // MARK: - Object Lifecycle
    static func generateInstance() -> GeneralViewController {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        return (storyboard.instantiateController(withIdentifier: kStoryboardIdGeneralViewController) as! GeneralViewController)
    }
    
    // MARK: - NSViewController Overrides
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if let account = KeychainUtility.accountInKeychain() {
            mailAddress = account.mailAddress as NSString
            password = account.password as NSString
        }
        
        validateCheckAccountButton()
    }

    // MARK: - Internal Functions
    private func validateCheckAccountButton() {
        checkAccountButton?.isEnabled = canLogin()
    }
    
    private func canLogin() -> Bool {
        if mailAddress == nil || password == nil {
            return false
        }
        
        let loginSelected = sessionManagementMatrix?.selectedTag() == SessionManagementType.login.rawValue
        let hasValidMailAddress = (mailAddress as String).hasRegexp(pattern: kRegexpMailAddress)
        let hasValidPassword = (password as String).hasRegexp(pattern: kRegexpPassword)
        
        return (loginSelected && hasValidMailAddress && hasValidPassword)
    }
    
    @IBAction func detectedChangeInSessionManagementMatrix(_ sender: AnyObject) {
        let matrix = (sender as! NSMatrix)
        // log.debug("\(matrix.selectedTag())")
        
        if matrix.selectedTag() == SessionManagementType.login.rawValue {
            mailAddressTextField.becomeFirstResponder()
        }
    }
    
    @IBAction func detectedEnterInTextField(_ sender: AnyObject) {
        if canLogin() {
            checkAccount(self)
        }
    }
    
    @IBAction func checkAccount(_ sender: AnyObject) {
        logger.debug("login w/ [\(self.mailAddress)][\(self.password)]")
        
        if canLogin() == false {
            return
        }
        
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
