import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataStd Real Array")
struct TDataStdRealArrayTests {

    @Test("Initialize and use real array")
    func initAndUse() {
        let doc = Document.create()!
        let label = doc.createLabel()!
        let ok = label.initRealArray(lower: 0, upper: 2)
        #expect(ok)

        if let bounds = label.realArrayBounds {
            #expect(bounds.lower == 0)
            #expect(bounds.upper == 2)
        }

        label.setRealArrayValue(at: 0, value: 1.1)
        label.setRealArrayValue(at: 1, value: 2.2)
        label.setRealArrayValue(at: 2, value: 3.3)

        if let v0 = label.realArrayValue(at: 0) { #expect(abs(v0 - 1.1) < 1e-10) }
        if let v1 = label.realArrayValue(at: 1) { #expect(abs(v1 - 2.2) < 1e-10) }
        if let v2 = label.realArrayValue(at: 2) { #expect(abs(v2 - 3.3) < 1e-10) }
    }
}
