//
//  IgnoreUrlRegistryType.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/10.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol IgnoreLiveRegistryType {
    func add(liveProgramId: String, seconds: TimeInterval)
    func shouldIgnore(liveProgramId: String) -> Bool
}
