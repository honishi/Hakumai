import XCTest
@testable import Hakumai

final class MessageContainerTests: XCTestCase {
    func testConsecutiveDebugMessagesUpdateOneRowAndPreserveSnapshots() {
        let container = MessageContainer()
        container.enableDebugMessage = true
        let first = container.append(debug: "Kusa rate 0%")
        XCTAssertTrue(first.appended)
        XCTAssertNil(first.updatedRow)
        let original = container.filteredMessagesSnapshot()

        for _ in 2...5 {
            let result = container.append(debug: "Kusa rate 0%")
            XCTAssertFalse(result.appended)
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result.updatedRow, 0)
        }
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["Kusa rate 0% x5"])
        XCTAssertEqual(texts(original), ["Kusa rate 0%"])
        XCTAssertEqual(container[0].messageNo, original[0].messageNo)
        XCTAssertEqual(container[0].date, original[0].date)
    }

    func testDifferentMessagesAndSystemMessagesBreakConsecutiveRuns() {
        let container = MessageContainer()
        container.enableDebugMessage = true
        container.append(debug: "A")
        container.append(debug: "B")
        container.append(debug: "A")
        container.append(systemMessage: "separator")
        container.append(debug: "A")
        container.append(debug: "A")
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["A", "B", "A", "separator", "A x2"])
    }

    func testEvenMutedCommentsBreakConsecutiveDebugRuns() {
        let container = MessageContainer()
        container.enableDebugMessage = true
        container.enableMuteWords = true
        container.muteWords = [[MuteUserWordKey.word: "muted"]]
        container.append(debug: "A")
        container.append(chat: Chat(roomPosition: .arena, no: 1, date: Date(), dateUsec: 0,
                                    mail: nil, userId: "1", comment: "muted", premium: .ippan, chatType: .comment))
        container.append(debug: "A")
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["A", "A"])
    }

    func testRebuildRestoresCountsAndIncludesMessagesAppendedDuringRebuild() {
        let container = MessageContainer()
        for _ in 0..<3 {
            container.append(debug: "A")
        }
        XCTAssertEqual(container.count(), 0)

        container.enableDebugMessage = true
        let finished = expectation(description: "フィルター再構築")
        container.rebuildFilteredMessages { finished.fulfill() }
        // バックグラウンド側のsnapshot取得前・取得後のどちらでも集約結果が一致する。
        container.append(debug: "A")
        container.append(debug: "A")
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["A x5"])

        container.enableDebugMessage = false
        rebuild(container)
        XCTAssertEqual(container.count(), 0)
        container.enableDebugMessage = true
        rebuild(container)
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["A x5"])
    }

    func testClearResetsRepeatCountAndOriginalTextIsUsedForComparison() {
        let container = MessageContainer()
        container.enableDebugMessage = true
        container.append(debug: "A")
        container.append(debug: "A")
        container.append(debug: "A x2")
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["A x2", "A x2"])

        container.removeAll()
        let result = container.append(debug: "A")
        XCTAssertTrue(result.appended)
        XCTAssertNil(result.updatedRow)
        XCTAssertEqual(texts(container.filteredMessagesSnapshot()), ["A"])
    }

    func testSearchMatchesTheDisplayedRepeatCount() {
        let container = MessageContainer()
        container.enableDebugMessage = true
        container.append(debug: "A")
        container.append(debug: "A")
        XCTAssertEqual(CommentSearchMatcher.matchedRowIndexes(
            messages: container.filteredMessagesSnapshot(), normalizedQuery: "x2", providerId: nil,
            handleNameResolver: { _, _ in nil }, cachedUserNameResolver: { _ in nil }
        ), [0])
    }

    func testSearchUpdatesMatchesWhenRepeatCountChanges() throws {
        var state = CommentSearchState()
        state.updateTypedQuery("x2")
        let request = try XCTUnwrap(state.beginSearch())
        state.finishSearch(matchedRows: [0], generation: request.generation)
        state.updateMatch(at: 0, isMatched: false)
        state.updateMatch(at: 1, isMatched: true)
        state.updateMatch(at: 1, isMatched: true)
        XCTAssertEqual(state.matchedRows, [1])
    }

    func testSearchAppliesRepeatChangesAfterItsOlderSnapshotCompletes() throws {
        var state = CommentSearchState()
        state.updateTypedQuery("x2")
        let request = try XCTUnwrap(state.beginSearch())
        state.updateMatch(at: 0, isMatched: false)
        state.appendMatchedRows([1])
        state.updateMatch(at: 1, isMatched: false)
        state.updateMatch(at: 2, isMatched: true)
        state.finishSearch(matchedRows: [0], generation: request.generation)
        XCTAssertEqual(state.matchedRows, [2])
    }

    private func rebuild(_ container: MessageContainer) {
        let finished = expectation(description: "フィルター再構築")
        container.rebuildFilteredMessages { finished.fulfill() }
        wait(for: [finished], timeout: 5)
    }

    private func texts(_ messages: [Message]) -> [String] {
        messages.map { message in
            switch message.content {
            case .debug(let debug): return debug.displayMessage
            case .system(let system): return system.message
            case .chat(let chat): return chat.comment
            }
        }
    }
}
