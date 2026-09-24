import Foundation
import XCTest
import Starscream
@testable import Hakumai

final class NicoManagerSessionTests: XCTestCase {
    func testManualConnectionResetsNDGRStateEvenIfWatchSocketRecoversBeforeNDGRStarts() {
        for programId in ["lv1", "lv2"] {
            let fixture = RecoveryFixture()
            let recorder = RecoveryRecorder()
            let manager = fixture.manager(recorder: recorder)
            let oldBeginAt = fixture.beginAt
            let newBeginAt = String(Int(Date().timeIntervalSince1970) - 1_000)
            fixture.view = { count, _ in
                switch count {
                case 1: return .ok(try RecoveryFixture.playlist(segment: "old", next: 100))
                case 2:
                    DispatchQueue.main.async {
                        fixture.beginAt = newBeginAt
                        fixture.sendMessageServer = false
                        manager.connect(liveProgramId: programId)
                    }
                    return .holding(Data())
                default: return .ok(try RecoveryFixture.playlist(segment: "new"))
                }
            }
            fixture.segment = { path in
                let data = try RecoveryFixture.comment(id: "shared-id", text: path)
                return .ok(try path == "/new" ? data + RecoveryFixture.end() : data)
            }
            recorder.onLog = { message in
                if message.contains("視聴用WS: 接続成功"), fixture.engines.count == 2 {
                    fixture.sendMessageServer = true
                    fixture.engines.last?.delegate?.didReceive(event: .error(URLError(.networkConnectionLost)))
                }
            }
            let ended = expectation(description: "手動接続後のWS復旧でも新しい履歴を取得")
            recorder.onDisconnect = { context in
                if case .normal = context, fixture.programRequests == 3 { ended.fulfill() }
            }
            manager.connect(liveProgramId: "lv1")
            wait(for: [ended], timeout: 5)
            XCTAssertEqual(fixture.viewPositions, [oldBeginAt, "100", newBeginAt])
            XCTAssertEqual(recorder.comments, ["/old", "/new"], "前セッションと同じmeta IDでも手動接続後は受信する")
            XCTAssertTrue(recorder.logs.contains { $0.contains("NDGR初回開始:") })
            manager.disconnect()
        }
    }
}
