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
    func kickTableViewStressTest() {
        // kickParallelTableViewStressTest(5, interval: 0.5, count: 100000)
        kickParallelTableViewStressTest(4, interval: 2, count: 100000)
        // kickParallelTableViewStressTest(1, interval: 0.01, count: 100)
    }

    func kickParallelTableViewStressTest(parallelism: Int, interval: NSTimeInterval, count: Int) {
        for _ in 1...parallelism {
            kickTableViewStressTest(interval, count: count)
            
            let randomWait = Float(arc4random() % 10) * 0.1
            NSThread.sleepForTimeInterval(NSTimeInterval(randomWait))
        }
    }
    
    func kickTableViewStressTest(interval: NSTimeInterval, count: Int) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            for _ in 1...count {
                let chat = self.randomChat()
                MainViewController.sharedInstance.nicoUtilityDidReceiveChat(NicoUtility.sharedInstance, chat: chat)
                NSThread.sleepForTimeInterval(interval)
            }
        }
        
        // NSRunLoop.currentRunLoop().run()
    }
    
    func randomChat() -> Chat {
        let chat = Chat()
        
        chat.roomPosition = RoomPosition.Arena
        chat.userId = "xxx" + String(arc4random() % 1000)
        chat.no = (Int(arc4random()) % 1000)
        chat.score = -(Int(arc4random()) % 30000)
        chat.comment = "hello " * (Int(arc4random()) % 100)
        chat.date = NSDate()
        chat.mail = ["184"]
        chat.premium = Premium.Premium
        
        return chat
    }
    
    // MARK: - Standard User Defaults
    func updateStandardUserDefaults() {
        let delay = 2.0 * Double(NSEC_PER_SEC)
        let time  = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue()) {
            let d = NSUserDefaults.standardUserDefaults()
            let v = d.boolForKey(Parameters.ShowIfseetnoCommands)
            d.setBool(!v, forKey: Parameters.ShowIfseetnoCommands)
            d.synchronize()
            logger.debug("")
        }
    }
}
