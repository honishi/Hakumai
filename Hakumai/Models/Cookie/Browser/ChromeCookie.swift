//
//  ChromeCookie.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import FMDB
import SAMKeychain
import XCGLogger

// file log
private let kFileLogName = "Hakumai_Chrome.log"

// sqlite
private let kDatabasePath = "/Google/Chrome/Default/Cookies"

// aes key
private let kSalt = "saltysalt"
private let kRoundCount = 1003

// decrypt
private let kInitializationVector = " " * 16

// keychain
private let kChromeServiceName = "Chrome Safe Storage"
private let kChromeAccount = "Chrome"

class ChromeCookie {
    // MARK: - Properties
    private static var fileLogger: XCGLogger!

    // MARK: - Public Functions
    // based on http://n8henrie.com/2014/05/decrypt-chrome-cookies-with-python/
    class func storedCookie() -> String? {
        ChromeCookie.setupFileLogger()
        
        let encryptedCookie = ChromeCookie.queryEncryptedCookie()
        fileLogger.debug("encryptedCookie:[\(encryptedCookie)]")
        
        if encryptedCookie == nil {
            return nil
        }
        
        let encryptedCookieByRemovingPrefix = ChromeCookie.encryptedCookieByRemovingPrefix(encryptedCookie!)
        fileLogger.debug("encryptedCookieByRemovingPrefix:[\(encryptedCookieByRemovingPrefix)]")
        
        if encryptedCookieByRemovingPrefix == nil {
            return nil
        }
        
        let password = ChromeCookie.chromePassword().data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let salt = kSalt.data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let aesKey = ChromeCookie.aesKeyForPassword(password, salt: salt, roundCount: kRoundCount)
        fileLogger.debug("aesKey:[\(aesKey)]")
        
        if aesKey == nil {
            return nil
        }
        
        let decrypted = ChromeCookie.decryptCookie(encryptedCookieByRemovingPrefix!, aesKey: aesKey!)
        fileLogger.debug("decrypted:[\(decrypted)]")
        
        if decrypted == nil {
            return nil
        }
        
        let decryptedString = ChromeCookie.decryptedStringByRemovingPadding(decrypted!)
        fileLogger.debug("decryptedString:[\(decryptedString)]")
        
        return decryptedString
    }
    
    // MARK: - Internal Functions
    private class func setupFileLogger() {
        guard fileLogger == nil else {
            return
        }
        
        fileLogger = XCGLogger()
        Helper.setupFileLogger(fileLogger, fileName: kFileLogName)
    }
    
    private class func queryEncryptedCookie() -> Data? {
        var encryptedCookie: Data?
        
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0] 
        let database = FMDatabase(path: appSupportDirectory + kDatabasePath)
        
        let query = NSString(format: "SELECT host_key, name, encrypted_value FROM cookies " +
            "WHERE host_key = '%@' and name = 'user_session'", ".nicovideo.jp")
        
        database?.open()
        
        let rows = database?.executeQuery(query as String, withArgumentsIn: [""])
        
        while (rows != nil && (rows?.next())!) {
            // var name = rows.stringForColumn("name")
            // logger.debug(name)
            
            let encryptedValue = rows?.data(forColumn: "encrypted_value")
            // logger.debug(encryptedValue)
            // we could not extract string from binary here
            
            if (0 < encryptedValue?.count) {
                encryptedCookie = encryptedValue
            }
        }
        
        database?.close()
        
        return encryptedCookie
    }
    
    private class func encryptedCookieByRemovingPrefix(_ encrypted: Data) -> Data? {
        let prefixString : NSString = "v10"
        // let rangeForDataWithoutPrefix = NSMakeRange(prefixString.length, encrypted.count - prefixString.length)
        let encryptedByRemovingPrefix = encrypted.subdata(in: prefixString.length..<encrypted.count)
        // logger.debug(encryptedByRemovingPrefix)
        
        return encryptedByRemovingPrefix
    }
    
    private class func chromePassword() -> String {
        let password = SAMKeychain.password(forService: kChromeServiceName, account: kChromeAccount)
        // logger.debug(password)
        
        return password!
    }
    
    // based on http://stackoverflow.com/a/25702855
    private class func aesKeyForPassword(_ password: Data, salt: Data, roundCount: Int) -> Data? {
        let passwordPointer = UnsafePointer<Int8>((password as NSData).bytes)
        let passwordLength = size_t(password.count)
        
        let saltPointer = UnsafePointer<UInt8>((salt as NSData).bytes)
        let saltLength = size_t(salt.count)
        
        let derivedKey = NSMutableData(length: kCCKeySizeAES128)!
        let derivedKeyPointer = UnsafeMutablePointer<UInt8>(derivedKey.mutableBytes)
        let derivedKeyLength = size_t(derivedKey.length)
        
        let result = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordPointer,
            passwordLength,
            saltPointer,
            saltLength,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
            UInt32(roundCount),
            derivedKeyPointer,
            derivedKeyLength)
        
        if result != 0 {
            logger.error("CCKeyDerivationPBKDF failed with error: '\(result)'")
            return nil
        }
        
        return derivedKey as Data
    }
    
    // based on http://stackoverflow.com/a/25755864
    private class func decryptCookie(_ encrypted: Data, aesKey: Data) -> Data? {
        let aesKeyPointer = UnsafePointer<UInt8>((aesKey as NSData).bytes)
        let aesKeyLength = size_t(kCCKeySizeAES128)
        // logger.debug("aesKeyPointer = \(aesKeyPointer), aesKeyLength = \(aesKeyData.length)")
        
        let encryptedPointer = UnsafePointer<UInt8>((encrypted as NSData).bytes)
        let encryptedLength = size_t(encrypted.count)
        // logger.debug("encryptedPointer = \(encryptedPointer), encryptedDataLength = \(encryptedLength)")
        
        let decryptedData: NSMutableData! = NSMutableData(length: Int(encryptedLength) + kCCBlockSizeAES128)
        let decryptedPointer = UnsafeMutablePointer<UInt8>(decryptedData.mutableBytes)
        let decryptedLength = size_t(decryptedData.length)
        
        var numBytesEncrypted :size_t = 0
        
        let cryptStatus = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(),
            aesKeyPointer,
            aesKeyLength,
            kInitializationVector,
            encryptedPointer,
            encryptedLength,
            decryptedPointer,
            decryptedLength,
            &numBytesEncrypted)
        
        if UInt32(cryptStatus) == UInt32(kCCSuccess) {
            decryptedData.length = Int(numBytesEncrypted)
            // logger.debug("decryptedData = \(decryptedData), decryptedLength = \(numBytesEncrypted)")
        }
        else {
            logger.error("Error: \(cryptStatus)")
        }
        
        return decryptedData as Data?
    }

    // http://stackoverflow.com/a/14205319
    private class func decryptedStringByRemovingPadding(_ data: Data) -> String? {
        let paddingCount = Int(UnsafePointer<UInt8>((data as NSData).bytes)[data.count - 1])
        fileLogger.debug("padding character count:[\(paddingCount)]")
        
        // NSRange(location: 0, length: data.count - paddingCount)
        let trimmedData = data.subdata(in: 0..<(data.count - paddingCount))
        
        return NSString(data: trimmedData, encoding: String.Encoding.utf8.rawValue) as? String
    }
}
