//
//  NicoUtility+Extractor.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/05.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import Ono

extension NicoUtility {
    static func extractEmbeddedDataPropertiesFromLivePage(html: Data) -> EmbeddedDataProperties? {
        guard let document = try? ONOXMLDocument.htmlDocument(with: html) else { return nil }
        let xpathDataProps = "//script[@id=\"embedded-data\"]/@data-props"
        let dataPropsElement = document.rootElement.firstChild(withXPath: xpathDataProps)
        guard let _dataPropsElement = dataPropsElement,
              !_dataPropsElement.isBlank,
              let data = _dataPropsElement.stringValue?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EmbeddedDataProperties.self, from: data)
    }

    func extractUsername(fromHtmlData htmlData: Data) -> String? {
        guard let document = try? ONOXMLDocument.htmlDocument(with: htmlData) else { return nil }
        let xpath = "//meta[@property=\"profile:username\"]/@content"
        return document.rootElement.firstChild(withXPath: xpath)?.stringValue
    }
}
