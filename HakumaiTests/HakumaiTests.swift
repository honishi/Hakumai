//
//  HakumaiTests.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit
import XCTest
@testable import Hakumai

final class HakumaiTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testCommentSearchMatcherMatchesCommentAndSystemMessages() {
        let messages = [
            makeChatMessage(messageNo: 0, userId: "101", comment: "hello world"),
            Message(messageNo: 1, system: "system notice"),
            makeChatMessage(messageNo: 2, userId: "202", comment: "another comment")
        ]

        XCTAssertEqual(
            CommentSearchMatcher.matchedRowIndexes(
                messages: messages,
                normalizedQuery: "hello",
                providerId: "provider",
                handleNameResolver: { userId, _ in userId == "101" ? "alice" : nil },
                cachedUserNameResolver: { userId in userId == "202" ? "bob" : nil }
            ),
            [0]
        )

        XCTAssertEqual(
            CommentSearchMatcher.matchedRowIndexes(
                messages: messages,
                normalizedQuery: "system",
                providerId: nil,
                handleNameResolver: { _, _ in nil },
                cachedUserNameResolver: { _ in nil }
            ),
            [1]
        )
    }

    func testCommentSearchMatcherMatchesHandleNamesCachedUserNamesAndIds() {
        let messages = [
            makeChatMessage(messageNo: 0, userId: "101", comment: "hello world"),
            makeChatMessage(messageNo: 1, userId: "202", comment: "another comment")
        ]

        XCTAssertEqual(
            CommentSearchMatcher.matchedRowIndexes(
                messages: messages,
                normalizedQuery: "alice",
                providerId: "provider",
                handleNameResolver: { userId, _ in userId == "101" ? "alice" : nil },
                cachedUserNameResolver: { _ in nil }
            ),
            [0]
        )

        XCTAssertEqual(
            CommentSearchMatcher.matchedRowIndexes(
                messages: messages,
                normalizedQuery: "bob",
                providerId: "provider",
                handleNameResolver: { _, _ in nil },
                cachedUserNameResolver: { userId in userId == "202" ? "bob" : nil }
            ),
            [1]
        )

        XCTAssertEqual(
            CommentSearchMatcher.matchedRowIndexes(
                messages: messages,
                normalizedQuery: "202",
                providerId: "provider",
                handleNameResolver: { _, _ in nil },
                cachedUserNameResolver: { _ in nil }
            ),
            [1]
        )
    }

    func testCommentSearchMatcherCachesUserLabelResolutionPerSearch() {
        let messages = (0..<100).map {
            makeChatMessage(messageNo: $0, userId: "999", comment: "same user \($0)")
        }
        var handleNameCallCount = 0
        var cachedUserNameCallCount = 0

        let matchedRows = CommentSearchMatcher.matchedRowIndexes(
            messages: messages,
            normalizedQuery: "resolved-name",
            providerId: "provider",
            handleNameResolver: { _, _ in
                handleNameCallCount += 1
                return nil
            },
            cachedUserNameResolver: { _ in
                cachedUserNameCallCount += 1
                return "resolved-name"
            }
        )

        XCTAssertEqual(matchedRows.count, 100)
        XCTAssertEqual(handleNameCallCount, 1)
        XCTAssertEqual(cachedUserNameCallCount, 1)
    }

    func testCommentSearchMatcherHandlesTenThousandMessages() {
        let messages = (0..<10_000).map {
            makeChatMessage(
                messageNo: $0,
                userId: "\(10_000 + $0)",
                comment: $0 == 9_999 ? "needle" : "comment \($0)"
            )
        }

        let matchedRows = CommentSearchMatcher.matchedRowIndexes(
            messages: messages,
            normalizedQuery: "needle",
            providerId: nil,
            handleNameResolver: { _, _ in nil },
            cachedUserNameResolver: { _ in nil }
        )

        XCTAssertEqual(matchedRows, [9_999])
    }

    func testCommentSearchStateDiscardsStaleSearchResult() throws {
        var state = CommentSearchState()
        state.updateTypedQuery("first")
        let request = try XCTUnwrap(state.beginSearch())

        state.updateTypedQuery("second")

        XCTAssertFalse(state.finishSearch(matchedRows: [0, 1], generation: request.generation))
        XCTAssertNil(state.appliedQuery)
        XCTAssertTrue(state.matchedRows.isEmpty)
        XCTAssertNil(state.highlightQuery)
    }

    func testCommentSearchStateMergesRowsAppendedDuringSearch() throws {
        var state = CommentSearchState()
        state.updateTypedQuery("needle")
        let request = try XCTUnwrap(state.beginSearch())

        state.appendMatchedRows([8, 9])

        XCTAssertTrue(state.finishSearch(matchedRows: [1, 4], generation: request.generation))
        XCTAssertEqual(state.matchedRows, [1, 4, 8, 9])
    }

    func testContextMenuCopiesTheSelectionOnlyWhenClickingInsideIt() {
        let selection = IndexSet([0, 2])
        XCTAssertEqual(MessageCopy.contextMenuRows(clickedRow: 2, selectedRows: selection, messageCount: 4), selection)
        XCTAssertEqual(MessageCopy.contextMenuRows(clickedRow: 1, selectedRows: selection, messageCount: 4), IndexSet(integer: 1))
        XCTAssertTrue(MessageCopy.contextMenuRows(clickedRow: -1, selectedRows: selection, messageCount: 4).isEmpty)
        XCTAssertTrue(MessageCopy.contextMenuRows(clickedRow: 4, selectedRows: selection, messageCount: 4).isEmpty)
        XCTAssertEqual(MessageCopy.contextMenuRows(clickedRow: 0, selectedRows: selection, messageCount: 1), IndexSet(integer: 0))
    }

    func testCopyIncludesCommentsDebugCountsAndSystemMessagesInDisplayOrder() {
        var debug = Message(messageNo: 1, debug: "Kusa rate 0%")
        debug.content = .debug(DebugMessage(message: "Kusa rate 0%", repeatCount: 5))
        let messages = [
            makeChatMessage(messageNo: 0, userId: "1", comment: "hello\nworld"),
            debug,
            Message(messageNo: 2, system: "Live closed.")
        ]
        XCTAssertEqual(MessageCopy.text(messages: messages, rows: IndexSet([2, 0, 1])),
                       "hello\nworld\nKusa rate 0% x5\nLive closed.")
        XCTAssertEqual(MessageCopy.text(messages: messages, rows: IndexSet(integer: 1)), "Kusa rate 0% x5")
        XCTAssertEqual(MessageCopy.text(messages: messages, rows: IndexSet([0, 2])), "hello\nworld\nLive closed.")
    }

    func testCopyIgnoresRowsThatNoLongerExistAndDoesNotClearClipboardForEmptySelection() {
        let messages = [Message(messageNo: 0, debug: "debug")]
        XCTAssertNil(MessageCopy.text(messages: messages, rows: []))
        XCTAssertNil(MessageCopy.text(messages: [], rows: IndexSet(integer: 0)))
        XCTAssertNil(MessageCopy.text(messages: messages, rows: IndexSet(integer: 10)))
        XCTAssertEqual(MessageCopy.text(messages: messages, rows: IndexSet([0, 10])), "debug")
    }

    func testTableSelectAllAndCopyUseStandardActions() {
        let source = CopyTableDataSource()
        let table = ClickTableView(frame: .zero)
        table.allowsMultipleSelection = true
        table.allowsColumnSelection = false
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message")))
        table.dataSource = source
        table.reloadData()
        var copiedRows: IndexSet?
        table.setCopyAction { copiedRows = $0 }
        let copyItem = NSMenuItem(title: "Copy", action: #selector(ClickTableView.copy(_:)), keyEquivalent: "c")

        XCTAssertFalse(table.validateUserInterfaceItem(copyItem))
        table.copy(nil)
        XCTAssertNil(copiedRows)
        table.selectAll(nil)
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integersIn: 0..<3))
        XCTAssertTrue(table.validateUserInterfaceItem(copyItem))
        table.copy(nil)
        XCTAssertEqual(copiedRows, IndexSet(integersIn: 0..<3))
        table.deselectAll(nil)
        XCTAssertFalse(table.validateUserInterfaceItem(copyItem))
        withExtendedLifetime(source) {}
    }

    private func makeChatMessage(
        messageNo: Int,
        userId: String,
        comment: String,
        premium: Premium = .ippan,
        chatType: ChatType = .comment
    ) -> Message {
        let chat = Chat(
            roomPosition: .arena,
            no: messageNo,
            date: Date(timeIntervalSince1970: TimeInterval(messageNo)),
            dateUsec: 0,
            mail: nil,
            userId: userId,
            comment: comment,
            premium: premium,
            chatType: chatType
        )
        return Message(messageNo: messageNo, chat: chat)
    }
}

private final class CopyTableDataSource: NSObject, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { 3 }
}
