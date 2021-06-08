//
//  AFError+Extensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/06/08.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Alamofire

extension AFError {
    var isNetworkError: Bool {
        switch self {
        case .sessionTaskFailed(let error as NSError):
            // https://qiita.com/akatsuki174/items/1b8c46253fa2231d2414
            return error.domain == NSURLErrorDomain
        default:
            return false
        }
    }
}
