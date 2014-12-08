//
//  MainViewControllerExtensions.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

extension MainViewController {
    // MARK: - NSTableView Performance
    func kickParallelTableViewStressTest(parallelism: Int, interval: NSTimeInterval, count: Int) {
        for _ in 1...parallelism {
            self.kickTableViewStressTest(interval, count: count)
            
            let randomWait = Float(arc4random() % 10) * 0.1
            NSThread.sleepForTimeInterval(NSTimeInterval(randomWait))
        }
    }
    
    func kickTableViewStressTest(interval: NSTimeInterval, count: Int) {
        let qualityOfServiceClass = Int(QOS_CLASS_BACKGROUND.value)
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        
        dispatch_async(backgroundQueue, {
            for _ in 1...count {
                let chat = self.randomChat()
                
                if let mainvc = MainViewController.instance() {
                    mainvc.nicoUtilityDidReceiveChat(NicoUtility.sharedInstance, chat: chat)
                }
                
                NSThread.sleepForTimeInterval(interval)
            }
            
        })
        
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
        chat.mail = "184"
        chat.premium = Premium.Premium
        
        return chat
    }
}
