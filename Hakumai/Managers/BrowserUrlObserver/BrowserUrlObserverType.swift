//
//  BrowserUrlObserverType.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/12/07.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation

protocol BrowserUrlObserverType {
    func setBrowserType(_ browser: BrowserInUseType)
    func start(delegate: BrowserUrlObserverDelegate)
    func stop()
    func ignoreLive(liveProgramId: String, seconds: TimeInterval)
}

protocol BrowserUrlObserverDelegate: AnyObject {
    func browserUrlObserver(_ browserUrlObserver: BrowserUrlObserverType, didGetUrl liveUrl: URL)
}
