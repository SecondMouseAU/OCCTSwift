import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.86.0: TDataStd Extended Attributes + ShapeFix + FindContigousEdges

@Suite("BooleanArray Tests")
struct BooleanArrayTests {
    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        let values: [Bool] = [true, false, true, false, true]
        #expect(doc.setBooleanArray(tag: 300, values: values))
        if let result = doc.booleanArray(tag: 300) {
            #expect(result.count == 5)
            #expect(result[0] == true)
            #expect(result[1] == false)
            #expect(result[2] == true)
        }
    }

    @Test func hasBooleanArray() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasBooleanArray(tag: 301))
        _ = doc.setBooleanArray(tag: 301, values: [true])
        #expect(doc.hasBooleanArray(tag: 301))
    }

    @Test func emptyArrayReturnsNil() {
        guard let doc = Document.create() else { return }
        #expect(doc.booleanArray(tag: 302) == nil)
    }
}
