//
//  DatabaseValueCacher.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/28.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class DatabaseValueCacher<T: Equatable> {
    enum CacheResult: Equatable {
        case cached(T?) // `.cached(nil)` means the value is cached as `nil`.
        case notCached
    }

    private var cache: [String: Any] = [:]

    func update(value: T?, for userId: String, in communityId: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let key = cacheKey(userId, communityId)
        cache[key] = value ?? NSNull()
    }

    func updateValueAsNil(for userId: String, in communityId: String) {
        update(value: nil, for: userId, in: communityId)
    }

    func cachedValue(for userId: String, in communityId: String) -> CacheResult {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let key = cacheKey(userId, communityId)
        guard let cached = cache[key] else {
            return .notCached
        }
        switch cached {
        case is NSNull:
            return .cached(nil)
        case let value as T:
            return .cached(value)
        default:
            fatalError()
        }
    }

    private func cacheKey(_ userId: String, _ communityId: String) -> String {
        return "\(userId):\(communityId)"
    }
}
