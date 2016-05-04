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
@objc(IsLoginSessionManagementTransformer) class IsLoginSessionManagementTransformer: NSValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    override func transformedValue(value: AnyObject!) -> AnyObject? {
        return value.integerValue == SessionManagementType.Login.rawValue ? NSNumber(bool: true) : NSNumber(bool: false)
    }
}

class GeneralViewController: NSViewController {
    // MARK: - Properties
    static let sharedInstance = GeneralViewController.generateInstance()

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
    class func generateInstance() -> GeneralViewController {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        return (storyboard.instantiateControllerWithIdentifier(kStoryboardIdGeneralViewController) as! GeneralViewController)
    }
    
    // MARK: - NSViewController Overrides
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if let account = KeychainUtility.accountInKeychain() {
            mailAddress = account.mailAddress
            password = account.password
        }
        
        validateCheckAccountButton()
    }

    // MARK: - Internal Functions
    private func validateCheckAccountButton() {
        checkAccountButton?.enabled = canLogin()
    }
    
    private func canLogin() -> Bool {
        if mailAddress == nil || password == nil {
            return false
        }
        
        let loginSelected = sessionManagementMatrix?.selectedTag() == SessionManagementType.Login.rawValue
        let hasValidMailAddress = (mailAddress as String).hasRegexpPattern(kRegexpMailAddress)
        let hasValidPassword = (password as String).hasRegexpPattern(kRegexpPassword)
        
        return (loginSelected && hasValidMailAddress && hasValidPassword)
    }
    
    @IBAction func detectedChangeInSessionManagementMatrix(sender: AnyObject) {
        let matrix = (sender as! NSMatrix)
        // log.debug("\(matrix.selectedTag())")
        
        if matrix.selectedTag() == SessionManagementType.Login.rawValue {
            mailAddressTextField.becomeFirstResponder()
        }
    }
    
    @IBAction func detectedEnterInTextField(sender: AnyObject) {
        if canLogin() {
            checkAccount(self)
        }
    }
    
    @IBAction func checkAccount(sender: AnyObject) {
        logger.debug("login w/ [\(mailAddress)][\(password)]")
        
        if canLogin() == false {
            return
        }
        
        let completion = { (userSessionCookie: String?) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                self.progressIndicator.stopAnimation(self)
                
                if userSessionCookie == nil {
                    self.checkAccountStatusLabel.stringValue = "Status: Failed"
                    return
                }
                
                self.checkAccountStatusLabel.stringValue = "Status: Success"
                
                KeychainUtility.removeAllAccountsInKeychain()
                KeychainUtility.setAccountToKeychainWith(self.mailAddress as String, password: self.password as String)
            }
        }

        progressIndicator.startAnimation(self)
        CookieUtility.requestLoginCookieWithMailAddress(mailAddress as String, password: password as String, completion: completion)
    }
}
