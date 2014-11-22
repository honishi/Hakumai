//
//  ChromeCookie.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

import XCGLogger

// sqlite
let databasePath = NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/Cookies"

// aes key
let kSalt = "saltysalt"
let kRoundCount = 1003

// decrypt
let kInitializationVector = "                "

let log = XCGLogger.defaultInstance()

class ChromeCookie {
    // Class variables not yet supported
    // class let log = XCGLogger.defaultInstance()
    
    // based on http://n8henrie.com/2014/05/decrypt-chrome-cookies-with-python/
    internal class func cookie() -> String? {
        let encryptedValue: NSData? = ChromeCookie.querySqlite()
        
        if encryptedValue == nil {
            return nil
        }
        
        let encryptedValueByRemovingPrefix = ChromeCookie.encryptedValueByRemovingPrefix(encryptedValue)
        
        if encryptedValueByRemovingPrefix == nil {
            return nil
        }
        
        let passwordString: String! = ChromeCookie.chromePassword()
        var error: NSError?
        
        let aesKeyData = ChromeCookie.aesKeyForPassword(passwordString, saltString: kSalt, roundCount: kRoundCount, error: &error)!
        // log.debug(aesKeyData)
        
        let decryptedCookieValue = ChromeCookie.decryptCookieValue(encryptedValueByRemovingPrefix!, aesKeyData: aesKeyData)
        log.debug("\(decryptedCookieValue)")
        
        return decryptedCookieValue
    }
    
    private class func querySqlite() -> NSData? {
        var cookieValue: NSData?
        
        let database = FMDatabase(path: databasePath)
        
        let query_cookie = NSString(format: "SELECT host_key, name, encrypted_value FROM cookies " +
            "WHERE host_key = '%@' and name = 'user_session'", ".nicovideo.jp")
        
        database.open()
        
        var rows = database.executeQuery(query_cookie, withArgumentsInArray: [""])
        
        while (rows != nil && rows.next()) {
            var name = rows.stringForColumn("name")
            // log.debug(name)
            
            var encryptedValue = rows.dataForColumn("encrypted_value")
            // log.debug(encryptedValue)
            // we could not extract string from binary here
            
            if (0 < encryptedValue.length) {
                cookieValue = encryptedValue
            }
        }
        
        database.close()
        
        return cookieValue
    }
    
    private class func encryptedValueByRemovingPrefix(encryptedValue: NSData!) -> NSData? {
        let prefixString : NSString = "v10"
        let prefixRange = NSMakeRange(prefixString.length, encryptedValue!.length - prefixString.length)
        let encryptedValueByRemovingPrefix = encryptedValue!.subdataWithRange(prefixRange)
        // log.debug(encryptedValueByRemovingPrefix)
        
        return encryptedValueByRemovingPrefix
    }
    
    private class func chromePassword() -> String {
        let password = SSKeychain.passwordForService("Chrome Safe Storage", account: "Chrome")
        log.debug(password)
        
        return password
    }
    
    // based on http://stackoverflow.com/a/25702855
    private class func aesKeyForPassword(passwordString: String, saltString: String, roundCount: Int, error: NSErrorPointer) -> NSData? {
        let nsDerivedKey: NSMutableData! = NSMutableData(length: kCCKeySizeAES128)
        var nsDerivedKeyPointer = UnsafeMutablePointer<UInt8>(nsDerivedKey.mutableBytes)
        let nsDerivedKeyLength = size_t(nsDerivedKey.length)
        
        let algorithm: CCPBKDFAlgorithm = CCPBKDFAlgorithm(kCCPBKDF2)
        let prf: CCPseudoRandomAlgorithm = CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1)
        
        let saltData: NSData! = saltString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        let saltBytes = UnsafePointer<UInt8>(saltData.bytes)
        let saltLength = size_t(saltData.length)
        
        let passwordData = passwordString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        let nsPassword = passwordString as NSString
        let nsPasswordPointer = UnsafePointer<Int8>(nsPassword.cStringUsingEncoding(NSUTF8StringEncoding))
        let nsPasswordLength = size_t(nsPassword.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        
        let result = CCKeyDerivationPBKDF(
            algorithm,
            nsPasswordPointer,
            nsPasswordLength,
            saltBytes,
            saltLength,
            prf,
            UInt32(roundCount),
            nsDerivedKeyPointer,
            nsDerivedKeyLength)
        
        if result != 0 {
            let errorDescription = "CCKeyDerivationPBKDF failed with error: '\(result)'"
            // error.memory = MyError(domain: ClientErrorType.errorDomain, code: Int(result), descriptionText: errorDescription)
            return nil
        }
        
        return nsDerivedKey
    }
    
    // based on http://stackoverflow.com/a/25755864
    private class func decryptCookieValue(encryptedData: NSData, aesKeyData: NSData) -> String? {
        let aesKeyBytes = UnsafePointer<UInt8>(aesKeyData.bytes)
        let aesKeyLength = size_t(kCCKeySizeAES128)
        // log.debug("aesKeyData = \(aesKeyData), aesKeyLength = \(aesKeyData.length)")
        
        let encryptedDataLength = UInt(encryptedData.length)
        let encryptedDataBytes = UnsafePointer<UInt8>(encryptedData.bytes)
        // log.debug("encryptedData = \(encryptedData), encryptedDataLength = \(encryptedDataLength)")
        
        let decryptedData: NSMutableData! = NSMutableData(length: Int(encryptedDataLength) + kCCBlockSizeAES128)
        var decryptedPointer = UnsafeMutablePointer<UInt8>(decryptedData.mutableBytes)
        let decryptedLength = size_t(decryptedData.length)
        
        let operation: CCOperation = UInt32(kCCDecrypt)
        let algoritm: CCAlgorithm = UInt32(kCCAlgorithmAES128)
        let options: CCOptions = UInt32(0)
        
        var numBytesEncrypted :UInt = 0
        
        var cryptStatus = CCCrypt(
            operation,
            algoritm,
            options,
            aesKeyBytes,
            aesKeyLength,
            kInitializationVector,
            encryptedDataBytes,
            encryptedDataLength,
            decryptedPointer,
            decryptedLength,
            &numBytesEncrypted)
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            decryptedData.length = Int(numBytesEncrypted)
            // log.debug("decryptedData = \(decryptedData), decryptedLength = \(numBytesEncrypted)")
        }
        else {
            log.error("Error: \(cryptStatus)")
        }
        
        // trim padding
        if let decryptedString = NSString(data: decryptedData, encoding: NSUTF8StringEncoding) {
            var error: NSError?
            let cleanseRegexp = NSRegularExpression(pattern: "(\n|\r)", options: nil, error: &error)
            let range = NSMakeRange(0, decryptedString.length)
            let cleansedString = cleanseRegexp?.stringByReplacingMatchesInString(decryptedString, options: nil, range: range, withTemplate: "")
            
            return cleansedString
        }
        
        return nil
    }
}