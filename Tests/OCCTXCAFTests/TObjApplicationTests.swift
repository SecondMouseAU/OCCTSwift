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
        if let app = TObjApplication.shared {
            app.isVerbose = true
            #expect(app.isVerbose)
            app.isVerbose = false
            #expect(!app.isVerbose)
        }
    }

    @Test func createDocument() {
        if let app = TObjApplication.shared {
            let doc = app.createDocument()
            #expect(doc != nil)
        }
    }
}
