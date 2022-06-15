//
//  KusaCommentDetectorType.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/11.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol KusaCommentDetectorType {
    func start(delegate: KusaCommentDetectorDelegate)
    func stop()
    func add(chat: Chat)
}

protocol KusaCommentDetectorDelegate: AnyObject {
    func kusaCommentDetectorDidDetectKusa(_ kusaCommentDetector: KusaCommentDetectorType)
    func kusaCommentDetector(_ kusaCommentDetector: KusaCommentDetectorType, hasDebugMessage message: String)
}
