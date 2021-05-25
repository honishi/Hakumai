//
//  NSXMLElementExtension.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/8/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

extension XMLElement {
    func firstStringValue(forXPath xpath: String) -> String? {
        var err: NSError?
        do {
            let nodes = try self.nodes(forXPath: xpath)
            if 0 < nodes.count {
                return (nodes[0]).stringValue
            }
        } catch let error as NSError {
            err = error
            log.debug("\(err?.debugDescription ?? "")")
        }
        return nil
    }

    func firstIntValue(forXPath xpath: String) -> Int? {
        guard let stringValue = firstStringValue(forXPath: xpath) else { return nil }
        return Int(stringValue)
    }
}
