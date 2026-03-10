//
//  HakumaiTests.swift
//  HakumaiTests
//
//  Created by Hiroyuki Onishi on 11/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
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
