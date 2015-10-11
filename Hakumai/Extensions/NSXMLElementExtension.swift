//
//  NSXMLElementExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/8/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

extension NSXMLElement {
    func firstStringValueForXPathNode(xpath: String) -> String? {
        var err: NSError?
        
        do {
            let nodes = try self.nodesForXPath(xpath)
            if 0 < nodes.count {
                return (nodes[0] ).stringValue
            }
        } catch let error as NSError {
            err = error
        }
        
        return nil
    }
    
    func firstIntValueForXPathNode(xpath: String) -> Int? {
        let stringValue = self.firstStringValueForXPathNode(xpath)
        
        return Int(stringValue?)
    }
}
