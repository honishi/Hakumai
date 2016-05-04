//
//  LoginCookie.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/6/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

private let kNicoVideoDomain = "http://nicovideo.jp"
private let kLoginUrl = "https://secure.nicovideo.jp/secure/login?site=niconico"

// request header
private let kUserAgent = kCommonUserAgent

class LoginCookie {
    // MARK: - Public Functions
    class func requestCookieWithMailAddress(mailAddress: String, password: String, completion: (userSessionCookie: String?) -> Void) {
        func httpCompletion(response: NSURLResponse?, data: NSData?, connectionError: NSError?) {
            if connectionError != nil {
                logger.error("login failed. connection error:[\(connectionError)]")
                completion(userSessionCookie: nil)
                return
            }
            
            let httpResponse = (response as! NSHTTPURLResponse)
            if httpResponse.statusCode != 200 {
                logger.error("login failed. got unexpected status code::[\(httpResponse.statusCode)]")
                completion(userSessionCookie: nil)
                return
            }

            let userSessionCookie = LoginCookie.findUserSessionCookie()
            logger.debug("found session cookie:[\(userSessionCookie)]")
            
            if userSessionCookie == nil {
                completion(userSessionCookie: nil)
                return
            }
            
            completion(userSessionCookie: userSessionCookie!)
        }
        
        LoginCookie.removeAllStoredCookie()
        
        let parameters = "mail=\(mailAddress)&password=\(password)"
        
        let request = NSMutableURLRequest(URL: NSURL(string: kLoginUrl)!)
        request.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        request.HTTPMethod = "POST"
        request.HTTPBody = parameters.dataUsingEncoding(NSUTF8StringEncoding)

        let queue = NSOperationQueue()
        NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler: httpCompletion)
    }
    
    // MARK: - Internal Functions
    private class func removeAllStoredCookie() {
        let cookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        let cookies = cookieStorage.cookiesForURL(NSURL(string: kNicoVideoDomain)!)
        
        if cookies == nil {
            return
        }
        
        for cookie in cookies! {
            cookieStorage.deleteCookie((cookie ))
        }
    }
    
    private class func findUserSessionCookie() -> String? {
        let cookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        let cookies = cookieStorage.cookiesForURL(NSURL(string: kNicoVideoDomain)!)
        
        if cookies == nil {
            return nil
        }
        
        for cookie in cookies! {
            let castedCookie = (cookie )
            if castedCookie.name == "user_session" {
                return castedCookie.value
            }
        }
        
        return nil
    }
}