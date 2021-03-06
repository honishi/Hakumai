//
//  User.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class User: CustomStringConvertible {
    let userId: String
    let nickname: String

    var description: String { "User: userId[\(userId)] nickname[\(nickname)]" }

    // MARK: - Object Lifecycle
    init(userId: String, nickname: String) {
        self.userId = userId
        self.nickname = nickname
    }
}
