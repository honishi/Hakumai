//
//  AuthModel.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/21.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let refreshToken: String
    // `idToken` is provided when `grant_type` = `authorization_code`, but
    // is not provided when it's `refresh_token`. So making this optional.
    let idToken: String?
}
