//
//  User.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/23/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct User {
    // MARK: - Properties
    let userId: String
    let nickname: String
}

extension User: CustomStringConvertible {
    var description: String { "User: userId[\(userId)] nickname[\(nickname)]" }
}
