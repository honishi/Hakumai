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
private let kChromePath = "/Google/Chrome/"
private let kDefaultPath = "Default/Cookies"

// aes key
private let kSalt = "saltysalt"
private let kRoundCount = 1003

// decrypt
private let kInitializationVector = " " * 16

// keychain
private let kChromeServiceName = "Chrome Safe Storage"
private let kChromeAccount = "Chrome"

final class ChromeCookie {

    // MARK: - Properties
    private static let fileLog: XCGLogger = {
        let logger = XCGLogger()
        Helper.setupFileLogger(logger, fileName: kFileLogName)
        return logger
    }()

    // MARK: - Public Functions
    // based on http://n8henrie.com/2014/05/decrypt-chrome-cookies-with-python/
    static func storedCookie() -> String? {
        guard let encryptedCookie = ChromeCookie.queryEncryptedCookie() else { return nil }

        fileLog.debug("encryptedCookie:[\(encryptedCookie)]")

        guard let encryptedCookieByRemovingPrefix = ChromeCookie.encryptedCookieByRemovingPrefix(encryptedCookie) else {
            return nil
        }
        fileLog.debug("encryptedCookieByRemovingPrefix:[\(encryptedCookieByRemovingPrefix)]")

        guard let password = ChromeCookie.chromePassword().data(using: String.Encoding.utf8, allowLossyConversion: false),
              let salt = kSalt.data(using: String.Encoding.utf8, allowLossyConversion: false),
              let aesKey = ChromeCookie.aesKeyForPassword(password, salt: salt, roundCount: kRoundCount) else {
            return nil
        }
        fileLog.debug("aesKey:[\(aesKey)]")

        guard let decrypted = ChromeCookie.decryptCookie(encryptedCookieByRemovingPrefix, aesKey: aesKey) else {
            return nil
        }
        fileLog.debug("decrypted:[\(decrypted)]")

        let decryptedString = ChromeCookie.decryptedStringByRemovingPadding(decrypted)
        fileLog.debug("decryptedString:[\(decryptedString ?? "")]")

        return decryptedString
    }
}

// MARK: - Internal Functions
private extension ChromeCookie {
    static func queryEncryptedCookie() -> Data? {
        var encryptedCookie: Data?

        var database: FMDatabase?
        let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
        if FileManager.default.fileExists(atPath: appSupportDirectory + kChromePath + kDefaultPath) {
            database = FMDatabase(path: appSupportDirectory + kChromePath + kDefaultPath)
        } else {
            let cookiePath = searchCookiesInProfileDir(atPath: appSupportDirectory + kChromePath)
            database = FMDatabase(path: cookiePath)
        }

        database?.open()

        let query = "SELECT host_key, name, encrypted_value FROM cookies WHERE host_key = '.nicovideo.jp' and name = 'user_session'"
        let rows = database?.executeQuery(query, withArgumentsIn: [""])

        while rows?.next() == true {
            // var name = rows.stringForColumn("name")
            // log.debug(name)

            let encryptedValue = rows?.data(forColumn: "encrypted_value")
            // log.debug(encryptedValue)
            // we could not extract string from binary here

            if let encryptedValue = encryptedValue, 0 < encryptedValue.count {
                encryptedCookie = encryptedValue
            }
        }

        database?.close()

        return encryptedCookie
    }

    static func encryptedCookieByRemovingPrefix(_ encrypted: Data) -> Data? {
        let prefixString: NSString = "v10"
        // let rangeForDataWithoutPrefix = NSMakeRange(prefixString.length, encrypted.count - prefixString.length)
        let encryptedByRemovingPrefix = encrypted.subdata(in: prefixString.length..<encrypted.count)
        // log.debug(encryptedByRemovingPrefix)
        return encryptedByRemovingPrefix
    }

    static func chromePassword() -> String {
        guard let password = SAMKeychain.password(forService: kChromeServiceName, account: kChromeAccount) else {
            return ""
        }
        // log.debug(password)
        return password
    }

    // based on http://stackoverflow.com/a/25702855
    static func aesKeyForPassword(_ password: Data, salt: Data, roundCount: Int) -> Data? {
        let passwordPointer = (password as NSData).bytes.assumingMemoryBound(to: Int8.self)
        let passwordLength = size_t(password.count)

        let saltPointer = (salt as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let saltLength = size_t(salt.count)

        guard let derivedKey = NSMutableData(length: kCCKeySizeAES128) else { return nil }
        let derivedKeyPointer = derivedKey.mutableBytes.assumingMemoryBound(to: UInt8.self)
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
            log.error("CCKeyDerivationPBKDF failed with error: '\(result)'")
            return nil
        }

        return derivedKey as Data
    }

    // based on http://stackoverflow.com/a/25755864
    static func decryptCookie(_ encrypted: Data, aesKey: Data) -> Data? {
        let aesKeyPointer = (aesKey as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let aesKeyLength = size_t(kCCKeySizeAES128)
        // log.debug("aesKeyPointer = \(aesKeyPointer), aesKeyLength = \(aesKeyData.length)")

        let encryptedPointer = (encrypted as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let encryptedLength = size_t(encrypted.count)
        // log.debug("encryptedPointer = \(encryptedPointer), encryptedDataLength = \(encryptedLength)")

        let decryptedData: NSMutableData! = NSMutableData(length: Int(encryptedLength) + kCCBlockSizeAES128)
        let decryptedPointer = decryptedData.mutableBytes.assumingMemoryBound(to: UInt8.self)
        let decryptedLength = size_t(decryptedData.length)

        var numBytesEncrypted: size_t = 0

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
            // log.debug("decryptedData = \(decryptedData), decryptedLength = \(numBytesEncrypted)")
        } else {
            log.error("Error: \(cryptStatus)")
        }

        return decryptedData as Data?
    }

    // http://stackoverflow.com/a/14205319
    static func decryptedStringByRemovingPadding(_ data: Data) -> String? {
        let paddingCount = Int((data as NSData).bytes.assumingMemoryBound(to: UInt8.self)[data.count - 1])
        fileLog.debug("padding character count:[\(paddingCount)]")

        // NSRange(location: 0, length: data.count - paddingCount)
        let trimmedData = data.subdata(in: 0..<(data.count - paddingCount))

        return NSString(data: trimmedData, encoding: String.Encoding.utf8.rawValue) as String?
    }

    static func searchCookiesInProfileDir(atPath filePath: String) -> String? {
        let defaultFileManager = FileManager.default
        do {
            let contents = try defaultFileManager.contentsOfDirectory(atPath: filePath)
            for content in contents {
                if content.hasPrefix("Profile") {
                    return filePath + content + "/Cookies"
                }
            }
        } catch {
            log.debug("No such file or directory")
            return ""
        }

        return ""
    }
}
