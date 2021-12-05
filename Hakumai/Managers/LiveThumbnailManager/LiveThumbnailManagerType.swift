//
//  LiveThumbnailManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/04.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol LiveThumbnailManagerType {
    func start(for liveProgramId: String, delegate: LiveThumbnailManagerDelegate)
    func stop()
}

protocol LiveThumbnailManagerDelegate: AnyObject {
    func liveThumbnailManager(_ liveThumbnailManager: LiveThumbnailManagerType, didGetThumbnailUrl thumbnailUrl: URL, forLiveProgramId liveProgramId: String)
}
