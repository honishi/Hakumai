//
//  KusaCheckerType.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/11.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol KusaCheckerType {
    func start(delegate: KusaCheckerDelegate)
    func stop()
    func add(chat: Chat)
}

protocol KusaCheckerDelegate: AnyObject {
    func kusaCheckerDidDetectKusa(_ kusaChecker: KusaCheckerType)
    func kusaChecker(_ kusaChecker: KusaCheckerType, hasDebugMessage message: String)
}
