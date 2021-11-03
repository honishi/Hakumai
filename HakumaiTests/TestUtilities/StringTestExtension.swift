//
//  StringTestExtension.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 2021/11/02.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// swiftlint:disable force_unwrapping
extension String {
    func resourceFileToData() -> Data {
        let bundle = Bundle(for: NicoManagerTests.self)
        let path = bundle.path(forResource: self, ofType: nil)
        let fileHandle = FileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()
        return data!
    }

    func resourceFileToString() -> String {
        let data = resourceFileToData()
        return String(data: data, encoding: .utf8)!
    }
}
// swiftlint:enable force_unwrapping
