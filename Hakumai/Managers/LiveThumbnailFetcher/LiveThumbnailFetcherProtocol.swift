//
//  LiveThumbnailFetcherProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol LiveThumbnailFetcherProtocol {
    func start(for liveProgramId: String, delegate: LiveThumbnailFetcherDelegate)
    func stop()
}

protocol LiveThumbnailFetcherDelegate: AnyObject {
    func liveThumbnailFetcher(_ liveThumbnailFetcher: LiveThumbnailFetcherProtocol, didGetThumbnailUrl thumbnailUrl: URL, forLiveProgramId liveProgramId: String)
}
