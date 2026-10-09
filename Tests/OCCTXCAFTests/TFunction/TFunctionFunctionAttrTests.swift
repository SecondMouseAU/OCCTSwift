import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TFunction Function Attribute Tests (v0.56.0)

@Suite("TFunction Function Attribute")
struct TFunctionFunctionAttrTests {

    @Test("Create function attribute")
    func createFunction() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        #expect(label.setFunctionAttribute())
        // Initially not failed
        #expect(!label.functionIsFailed)
    }

    @Test("Function failure mode")
    func functionFailure() {
        let doc = Document.create()!
        let label = doc.createLabel()!

        label.setFunctionAttribute()
        #expect(label.setFunctionFailure(1))
        #expect(label.functionIsFailed)
        if let failure = label.functionFailure {
            #expect(failure == 1)
        }
    }
}
