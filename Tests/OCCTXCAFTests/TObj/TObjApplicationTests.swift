import Foundation
import Testing

@testable import OCCTSwift

@Suite("TObj_Application Tests")
struct TObjApplicationTests {
    @Test func getInstance() {
        let app = TObjApplication.shared
        #expect(app != nil)
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

    @Test func createDocument() {
        OCCTSerial.withLock {
            if let app = TObjApplication.shared {
                let doc = app.createDocument()
                #expect(doc != nil)
            }
        }
    }
}
