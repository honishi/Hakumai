//
//  AudioCaptureManagerProtocol.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/11.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol AudioCaptureManagerType {
    func start(_ delegate: AudioCaptureManagerDelegate)
    func stop()
    // var isRunning: Bool { get }
}

protocol AudioCaptureManagerDelegate: AnyObject {
    func audioCaptureManager(_ audioCaptureManager: AudioCaptureManagerType, didCapture data: Data)
}
