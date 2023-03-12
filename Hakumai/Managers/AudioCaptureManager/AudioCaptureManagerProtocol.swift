//
//  AudioCaptureManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/11.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol AudioCaptureManagerType {
    func start()
    func stop()
    func requestLatestCapture(completion: (Data?) -> Void)
    var isRunning: Bool { get }
}
