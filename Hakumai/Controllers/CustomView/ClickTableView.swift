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
    private var copyHandler: ((IndexSet) -> Void)?
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

    func setCopyAction(_ handler: @escaping (IndexSet) -> Void) {
        copyHandler = handler
    }

    @objc func copy(_ sender: Any?) {
        guard !selectedRowIndexes.isEmpty else { return }
        copyHandler?(selectedRowIndexes)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)) {
            return copyHandler != nil && !selectedRowIndexes.isEmpty
        }
        return super.validateUserInterfaceItem(item)
    }

    @objc func rowClicked(_ sender: AnyObject?) {
        // log.debug("\(clickedRow), \(selectedRow)")
        guard let clickHandler = clickHandler else {
            let modifiers = NSApp.currentEvent?.modifierFlags ?? []
            if allowsMultipleSelection && !modifiers.isDisjoint(with: [.command, .shift]) {
                // 複数選択を追加しても「同じ行を通常クリックし直すと解除」という従来操作を残す。
                // Command / Shift の選択は NSTableView に任せ、通常クリックの連続判定だけリセットする。
                lastClickedRow = -1
            } else {
                unclickRow()
            }
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
