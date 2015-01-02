//
//  NicoUtilityHttpClient.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/1/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// request header
private let kUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36"

// Internal Http Utility
extension NicoUtility {
    func cookiedAsyncRequest(httpMethod: String, url: NSURL, parameters: [String: Any]?, completion: (NSURLResponse!, NSData!, NSError!) -> Void) {
        self.cookiedAsyncRequest(httpMethod, url: url.absoluteString!, parameters: parameters, completion: completion)
    }
    
    func cookiedAsyncRequest(httpMethod: String, url: String, parameters: [String: Any]?, completion: (NSURLResponse!, NSData!, NSError!) -> Void) {
        var parameteredUrl: String = url
        let constructedParameters = self.constructParameters(parameters)
        
        if httpMethod == "GET" && constructedParameters != nil {
            parameteredUrl += "?" + constructedParameters!
        }
        
        var request = self.mutableRequestWithCustomHeaders(parameteredUrl)
        request.HTTPMethod = httpMethod
        
        if httpMethod == "POST" && constructedParameters != nil {
            request.HTTPBody = constructedParameters!.dataUsingEncoding(NSUTF8StringEncoding)
        }
        
        if let cookie = self.sessionCookie() {
            let requestHeader = NSHTTPCookie.requestHeaderFieldsWithCookies([cookie])
            request.allHTTPHeaderFields = requestHeader
        }
        else {
            log.error("could not get cookie")
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
                constructed = constructed + "&"
            }
            
            constructed = constructed + "\(key)=\(value)"
        }
        
        // use custom escape character sets instead of NSCharacterSet.URLQueryAllowedCharacterSet()
        // cause we need to escape strings like this: tpos=1416842780%2E802121&comment%5Flocale=ja%2Djp
        var allowed = NSMutableCharacterSet.alphanumericCharacterSet()
        allowed.addCharactersInString("?=&")
        
        return constructed.stringByAddingPercentEncodingWithAllowedCharacters(allowed)
    }
    
    private func mutableRequestWithCustomHeaders(url: String) -> NSMutableURLRequest {
        let urlObject = NSURL(string: url)!
        var mutableRequest = NSMutableURLRequest(URL: urlObject)
        
        mutableRequest.setValue(kUserAgent, forHTTPHeaderField: "User-Agent")
        
        return mutableRequest
    }
    
    private func sessionCookie() -> NSHTTPCookie? {
        if let cookie = self.cookie {
            // log.debug("cookie:[\(cookie)]")
            
            let userSessionCookie = NSHTTPCookie(properties: [
                NSHTTPCookieDomain: "nicovideo.jp",
                NSHTTPCookieName: "user_session",
                NSHTTPCookieValue: cookie,
                NSHTTPCookieExpires: NSDate().dateByAddingTimeInterval(7200),
                NSHTTPCookiePath: "/"])
            
            return userSessionCookie
        }
        
        return nil
    }
}