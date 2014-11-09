//
//  NicoUtility.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/10/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

let kGetPlayerStatuUrl = "http://watch.live.nicovideo.jp/api/getplayerstatus?v=lv"

private let nicoutility = NicoUtility()

class NicoUtility : NSObject {
    
    private override init() {
        super.init()
    }
    
    class func getInstance() -> NicoUtility {
        return nicoutility
    }
    
    func getPlayerStatus() {
        let url = NSURL(string: kGetPlayerStatuUrl + "199619512")!
        var request = NSMutableURLRequest(URL: url)
        
        let requestHeader = NSHTTPCookie.requestHeaderFieldsWithCookies([self.sessionCookie()!])
        request.allHTTPHeaderFields = requestHeader
        
        let completionHandler = {(response: NSURLResponse?, data: NSData?, connectionError: NSError?) -> Void in
            let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
            println(responseString)
        }
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: completionHandler)
    }
    
    func sessionCookie() -> NSHTTPCookie? {
        let userSessionCookie = NSHTTPCookie(properties: [
            NSHTTPCookieDomain: "nicovideo.jp",
            NSHTTPCookieName: "user_session",
            NSHTTPCookieValue: CookieUtility.chromeCookie()!,
            NSHTTPCookieExpires: NSDate().dateByAddingTimeInterval(7200),
            NSHTTPCookiePath: "/"])
        
        return userSessionCookie
    }
}