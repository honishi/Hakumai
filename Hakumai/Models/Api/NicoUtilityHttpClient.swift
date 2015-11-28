//
//  NicoUtilityHttpClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// request header
private let kUserAgent = kCommonUserAgent
private let kCookieDomain = "nicovideo.jp"
private let kCookieExpire = NSTimeInterval(7200)
private let kCookiePath = "/"

// Internal Http Utility
extension NicoUtility {
    func cookiedAsyncRequest(httpMethod: String, url: NSURL, parameters: [String: Any]?, completion: (NSURLResponse?, NSData?, NSError?) -> Void) {
        cookiedAsyncRequest(httpMethod, url: url.absoluteString, parameters: parameters, completion: completion)
    }
    
    func cookiedAsyncRequest(httpMethod: String, url: String, parameters: [String: Any]?, completion: (NSURLResponse?, NSData?, NSError?) -> Void) {
        var parameteredUrl: String = url
        let constructedParameters = constructParameters(parameters)
        
        if httpMethod == "GET" && constructedParameters != nil {
            parameteredUrl += "?" + constructedParameters!
        }
        
        let request = mutableRequestWithCustomHeaders(parameteredUrl)
        request.HTTPMethod = httpMethod
        
        if httpMethod == "POST" && constructedParameters != nil {
            request.HTTPBody = constructedParameters!.dataUsingEncoding(NSUTF8StringEncoding)
        }
        
        if let cookies = sessionCookies() {
            let requestHeader = NSHTTPCookie.requestHeaderFieldsWithCookies(cookies)
            request.allHTTPHeaderFields = requestHeader
        }
        else {
            logger.error("could not get cookie")
            completion(nil, nil, NSError(domain:"", code:0, userInfo: nil))
        }
        
        let queue = NSOperationQueue()
        NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler: completion)
    }
    
    func constructParameters(parameters: [String: Any]?) -> String? {
        if parameters == nil {
            return nil
        }
        
        var constructed: NSString = ""
        
        for (key, value) in parameters! {
            if 0 < constructed.length {
                constructed = constructed as String + "&"
            }
            
            constructed = constructed as String + "\(key)=\(value)"
        }
        
        // use custom escape character sets instead of NSCharacterSet.URLQueryAllowedCharacterSet()
        // cause we need to escape strings like this: tpos=1416842780%2E802121&comment%5Flocale=ja%2Djp
        let allowed = NSMutableCharacterSet.alphanumericCharacterSet()
        allowed.addCharactersInString("?=&")
        
        return constructed.stringByAddingPercentEncodingWithAllowedCharacters(allowed)
    }
    
    private func mutableRequestWithCustomHeaders(url: String) -> NSMutableURLRequest {
        let urlObject = NSURL(string: url)!
        let mutableRequest = NSMutableURLRequest(URL: urlObject)
        
        mutableRequest.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        
        return mutableRequest
    }
    
    private func sessionCookies() -> [NSHTTPCookie]? {
        // logger.debug("userSessionCookie:[\(userSessionCookie)]")
        if userSessionCookie == nil {
            return nil
        }
        
        var cookies = [NSHTTPCookie]()
        
        for (name, value) in [("user_session", userSessionCookie!), ("area", "JP"), ("lang", "ja-jp")] {
            if let cookie = NSHTTPCookie(properties: [
                NSHTTPCookieDomain: kCookieDomain,
                NSHTTPCookieName: name,
                NSHTTPCookieValue: value,
                NSHTTPCookieExpires: NSDate().dateByAddingTimeInterval(kCookieExpire),
                NSHTTPCookiePath: kCookiePath]) {
                cookies.append(cookie)
            }
        }
        
        return cookies
    }
}