//
//  StoreCommentDetectorType.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/06/13.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol StoreCommentDetectorType {
    func isStoreComment(chat: Chat) -> Bool
}
