//
//  KeychainUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/6/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import SAMKeychain

class KeychainUtility {
    // MARK: - Public Functions
    static func removeAllAccountsInKeychain() {
        let serviceName = KeychainUtility.keychainServiceName()
        
        if let accounts = SAMKeychain.accounts(forService: serviceName) {
            for account in accounts {
                if let accountName = account[kSAMKeychainAccountKey] as? NSString {
                    if SAMKeychain.deletePassword(forService: serviceName, account: accountName as String) == true {
                        logger.debug("completed to delete account from keychain:[\(accountName)]")
                    }
                    else {
                        logger.error("failed to delete account from keychain:[\(accountName)]")
                    }
                }
            }
        }
    }
    
    static func setAccountToKeychain(mailAddress: String, password: String) {
        let serviceName = KeychainUtility.keychainServiceName()
        
        if SAMKeychain.setPassword(password, forService: serviceName, account: mailAddress) == true {
            logger.debug("completed to set account into keychain:[\(mailAddress)]")
        }
        else {
            logger.error("failed to set account into keychain:[\(mailAddress)]")
        }
    }
    
    static func accountInKeychain() -> (mailAddress: String, password: String)? {
        let serviceName = KeychainUtility.keychainServiceName()
        
        if let accounts = SAMKeychain.accounts(forService: serviceName) {
            guard let accountName = accounts.last?[kSAMKeychainAccountKey] as? String else {
                return nil
            }
            
            guard let password = SAMKeychain.password(forService: serviceName, account: accountName) else {
                return nil
            }

            logger.debug("found account in keychain:[\(accountName)]")
            return (accountName, password)
        }
        
        logger.debug("found no account in keychain")
        return nil
    }
    
    private static func keychainServiceName() -> String {
        var bundleIdentifier = ""
        if let bi = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String {
            bundleIdentifier = bi
        }
        
        return bundleIdentifier + ".account"
    }
}
