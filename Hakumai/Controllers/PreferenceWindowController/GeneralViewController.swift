//
//  GeneralViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/11/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCGLogger

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
    @IBOutlet weak var sessionManagementMatrix: NSMatrix!
    @IBOutlet weak var mailAddressTextField: NSTextField!
    @IBOutlet weak var checkAccountButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var checkAccountStatusLabel: NSTextField!
    
    dynamic var mailAddress: NSString! {
        didSet {
            self.validateCheckAccountButton()
        }
    }
    dynamic var password: NSString! {
        didSet {
            self.validateCheckAccountButton()
        }
    }
    
    private let log = XCGLogger.defaultInstance()
    
    // MARK: - Object Lifecycle
    class var sharedInstance : GeneralViewController {
        struct Static {
            static let instance : GeneralViewController = GeneralViewController.generateInstance()!
        }
        return Static.instance
    }

    class func generateInstance() -> GeneralViewController? {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)!
        return (storyboard.instantiateControllerWithIdentifier(kStoryboardIdGeneralViewController) as GeneralViewController)
    }
    
    // MARK: - NSViewController Overrides
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if let account = KeychainUtility.accountInKeychain() {
            self.mailAddress = account.mailAddress
            self.password = account.password
        }
        
        self.validateCheckAccountButton()
    }

    // MARK: - Internal Functions
    func validateCheckAccountButton() {
        self.checkAccountButton?.enabled = self.canLogin()
    }
    
    func canLogin() -> Bool {
        if self.mailAddress == nil || self.password == nil {
            return false
        }
        
        let loginSelected = self.sessionManagementMatrix?.selectedTag() == SessionManagementType.Login.rawValue
        let hasValidMailAddress = (self.mailAddress as String).hasRegexpPattern(kRegexpMailAddress)
        let hasValidPassword = (self.password as String).hasRegexpPattern(kRegexpPassword)
        
        return (loginSelected && hasValidMailAddress && hasValidPassword)
    }
    
    @IBAction func detectedChangeInSessionManagementMatrix(sender: AnyObject) {
        let matrix = (sender as NSMatrix)
        // log.debug("\(matrix.selectedTag())")
        
        if matrix.selectedTag() == SessionManagementType.Login.rawValue {
            self.mailAddressTextField.becomeFirstResponder()
        }
    }
    
    @IBAction func detectedEnterInTextField(sender: AnyObject) {
        if self.canLogin() {
            self.checkAccount(self)
        }
    }
    
    @IBAction func checkAccount(sender: AnyObject) {
        log.debug("login w/ [\(self.mailAddress)][\(self.password)]")
        
        if self.canLogin() == false {
            return
        }
        
        let completion = { (userSessionCookie: String?) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.progressIndicator.stopAnimation(self)
                
                if userSessionCookie == nil {
                    self.checkAccountStatusLabel.stringValue = "Status: Failed"
                    return
                }
                
                self.checkAccountStatusLabel.stringValue = "Status: Success"
                
                KeychainUtility.removeAllAccountsInKeychain()
                KeychainUtility.setAccountToKeychainWith(self.mailAddress, password: self.password)
            })
        }

        self.progressIndicator.startAnimation(self)
        CookieUtility.requestLoginCookieWithMailAddress(self.mailAddress, password: self.password, completion: completion)
    }
}
