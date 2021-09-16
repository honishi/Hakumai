//
//  UnclickableTableView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/09/15.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class ClickTableView: NSTableView {
    private var clickHandler: (() -> Void)?
    private var doubleClickHandler: (() -> Void)?
    private var lastClickedRow = -1
}

extension ClickTableView {
    override func awakeFromNib() {
        configure()
    }

    func setClickAction(clickHandler: (() -> Void)? = nil, doubleClickHandler: (() -> Void)? = nil) {
        self.clickHandler = clickHandler
        self.doubleClickHandler = doubleClickHandler
    }

    @objc func rowClicked(_ sender: AnyObject?) {
        // log.debug("\(clickedRow), \(selectedRow)")
        guard let clickHandler = clickHandler else {
            unclickRow()
            return
        }
        clickHandler()
    }

    @objc func rowDoubleClicked(_ sender: AnyObject?) {
        // log.debug("\(clickedRow), \(selectedRow)")
        guard let doubleClickHandler = doubleClickHandler else { return }
        doubleClickHandler()
    }
}

private extension ClickTableView {
    func configure() {
        target = self
        action = #selector(ClickTableView.rowClicked(_:))
        doubleAction = #selector(ClickTableView.rowDoubleClicked(_:))
    }

    func unclickRow() {
        guard clickedRow != -1 else { return }
        if lastClickedRow == clickedRow {
            deselectRow(clickedRow)
            lastClickedRow = -1
        } else {
            lastClickedRow = clickedRow
        }
    }
}
