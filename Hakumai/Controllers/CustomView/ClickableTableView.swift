//
//  UnclickableTableView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/09/15.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

final class ClickableTableView: NSTableView {
    private var onClick: (() -> Void)?
    private var onDoubleClick: (() -> Void)?
    private var lastClickedRow = -1
}

extension ClickableTableView {
    func setClickAction(onClick: (() -> Void)? = nil, onDoubleClick: (() -> Void)? = nil) {
        self.onClick = onClick
        self.onDoubleClick = onDoubleClick
        configure()
    }

    @objc func rowClicked(_ sender: AnyObject?) {
        // log.debug("\(clickedRow), \(selectedRow)")
        guard let onClick = onClick else {
            unclickRow()
            return
        }
        onClick()
    }

    @objc func rowDoubleClicked(_ sender: AnyObject?) {
        // log.debug("\(clickedRow), \(selectedRow)")
        guard let onDoubleClick = onDoubleClick else { return }
        onDoubleClick()
    }
}

private extension ClickableTableView {
    func configure() {
        target = self
        action = #selector(ClickableTableView.rowClicked(_:))
        doubleAction = #selector(ClickableTableView.rowDoubleClicked(_:))
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
