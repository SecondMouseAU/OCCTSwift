import Foundation
import Testing

@testable import OCCTSwift

// MARK: - TDataStd Array Attribute Tests (v0.55.0)

@Suite("TDataStd Integer Array")
struct TDataStdIntegerArrayTests {

    @Test("Initialize and use integer array")
    func initAndUse() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.initIntegerArray(lower: 1, upper: 5)
        #expect(ok)

        if let bounds = label.integerArrayBounds {
            #expect(bounds.lower == 1)
            #expect(bounds.upper == 5)
        }

        label.setIntegerArrayValue(at: 1, value: 10)
        label.setIntegerArrayValue(at: 3, value: 30)
        label.setIntegerArrayValue(at: 5, value: 50)

        #expect(label.integerArrayValue(at: 1) == 10)
        #expect(label.integerArrayValue(at: 3) == 30)
        #expect(label.integerArrayValue(at: 5) == 50)
    }

    @Test("Out of bounds returns nil")
    func outOfBounds() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        label.initIntegerArray(lower: 0, upper: 2)
        #expect(label.integerArrayValue(at: 99) == nil)
    }
}
