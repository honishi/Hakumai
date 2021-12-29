//
//  DatabaseValueCacher.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/28.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

class DatabaseValueCacher<T: Equatable> {
    enum CacheStatus: Equatable {
        case cached(T?) // `.cached(nil)` means the value is cached as `nil`.
        case notCached
    }

    private var cache: [String: CacheStatus] = [:]

    func update(value: T?, for userId: String, in communityId: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let key = cacheKey(userId, communityId)
        let _value: CacheStatus = {
            guard let value = value else { return .cached(nil) }
            return .cached(value)
        }()
        cache[key] = _value
    }

    func updateValueAsNil(for userId: String, in communityId: String) {
        update(value: nil, for: userId, in: communityId)
    }

    func cachedValue(for userId: String, in communityId: String) -> CacheStatus {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        let key = cacheKey(userId, communityId)
        return cache[key] ?? .notCached
    }

    private func cacheKey(_ userId: String, _ communityId: String) -> String {
        return "\(userId):\(communityId)"
    }
}
