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
        
        if let nodes = self.nodesForXPath(xpath, error: &err) {
            if 0 < nodes.count {
                return (nodes[0] as NSXMLNode).stringValue
            }
        }
        
        return nil
    }
    
    func firstIntValueForXPathNode(xpath: String) -> Int? {
        let stringValue = self.firstStringValueForXPathNode(xpath)
        
        return stringValue?.toInt()
    }
}
