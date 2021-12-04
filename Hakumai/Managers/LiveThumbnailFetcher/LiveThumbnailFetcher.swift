//
//  LiveThumbnailFetcher.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

final class LiveThumbnailFetcher {
    //
}

extension LiveThumbnailFetcher: LiveThumbnailFetcherProtocol {
    func start(for liveProgramId: String, delegate: LiveThumbnailFetcherDelegate) {
        //
    }

    func stop() {
        //
    }
}

private extension LiveThumbnailFetcher {
    func extractLiveThumbnailUrl(from html: String) -> URL? {
        return nil
    }
}

// Extension for unit testing.
// https://stackoverflow.com/a/50136916/13220031
#if DEBUG
extension LiveThumbnailFetcher {
    func exposedExtractLiveThumbnailUrl(from html: String) -> URL? {
        return extractLiveThumbnailUrl(from: html)
    }
}
#endif
