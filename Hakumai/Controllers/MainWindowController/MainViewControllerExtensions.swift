//
//  MainViewControllerExtensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// MainViewController test utility collection
extension MainViewController {
    // MARK: - NSTableView Performance
    private func kickTableViewStressTest() {
        // kickParallelTableViewStressTest(5, interval: 0.5, count: 100000)
        kickParallelTableViewStressTest(4, interval: 2, count: 100000)
        // kickParallelTableViewStressTest(1, interval: 0.01, count: 100)
    }

    private func kickParallelTableViewStressTest(_ parallelism: Int, interval: TimeInterval, count: Int) {
        for _ in 1...parallelism {
            kickTableViewStressTest(interval, count: count)
            
            let randomWait = Float(arc4random() % 10) * 0.1
            Foundation.Thread.sleep(forTimeInterval: TimeInterval(randomWait))
        }
    }
    
    private func kickTableViewStressTest(_ interval: TimeInterval, count: Int) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            for _ in 1...count {
                let chat = self.randomChat()
                MainViewController.sharedInstance.nicoUtilityDidReceiveChat(NicoUtility.sharedInstance, chat: chat)
                Foundation.Thread.sleep(forTimeInterval: interval)
            }
        }
        
        // NSRunLoop.currentRunLoop().run()
    }
    
    private func randomChat() -> Chat {
        let chat = Chat()
        
        chat.roomPosition = RoomPosition.arena
        chat.userId = "xxx" + String(arc4random() % 1000)
        chat.no = (Int(arc4random()) % 1000)
        chat.score = -(Int(arc4random()) % 30000)
        chat.comment = "hello " * (Int(arc4random()) % 100)
        chat.date = Date()
        chat.mail = ["184"]
        chat.premium = Premium.premium
        
        return chat
    }
    
    // MARK: - Standard User Defaults
    private func updateStandardUserDefaults() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let d = UserDefaults.standard
            let v = d.bool(forKey: Parameters.ShowIfseetnoCommands)
            d.set(!v, forKey: Parameters.ShowIfseetnoCommands)
            d.synchronize()
            logger.debug("")
        }
    }
}
