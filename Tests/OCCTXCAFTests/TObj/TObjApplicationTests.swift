import Foundation
import Testing

@testable import OCCTSwift

@Suite("TObj_Application Tests")
struct TObjApplicationTests {
    @Test func getInstance() throws {
        // OCCTSerial.withLock: see verboseFlag below, the singleton's field is unsynchronised.
        try OCCTSerial.withLock {
            let first = try #require(TObjApplication.shared)
            first.isVerbose = true
            // A second fetch is the same singleton, so it sees what the first one set.
            let second = try #require(TObjApplication.shared)
            #expect(second.isVerbose)
            second.isVerbose = false
            #expect(!first.isVerbose)
        }
    }

    @Test func verboseFlag() {
        // isVerbose mutates the shared singleton's plain field with no synchronization (see
        // TObjApplication's own doc comment, #1404); OCCTSerial.withLock is its documented
        // mitigation, needed here so this doesn't race Issue1588TObjApplicationReleaseTests'
        // own locked accesses to the same singleton under Swift Testing's parallel execution.
        OCCTSerial.withLock {
            if let app = TObjApplication.shared {
                app.isVerbose = true
                #expect(app.isVerbose)
                app.isVerbose = false
                #expect(!app.isVerbose)
            }
        }
    }

    @Test func createDocument() throws {
        try OCCTSerial.withLock {
            let app = try #require(TObjApplication.shared)
            let doc = try #require(app.createDocument())
            // A new TObj document holds no shapes.
            #expect(doc.rootNodes.isEmpty)
            #expect(doc.shapeCount == 0)
        }
    }
}
