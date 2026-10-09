import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc DimTol Tests")
struct XCAFDocDimTolTests {

    @Test func setAndGet() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setDimTol(
            labelId: node.labelId, kind: 1, values: [0.01, 0.05],
            name: "Flatness", description: "Surface flatness tolerance")
        doc.commitTransaction()

        if let kind = doc.dimTolKind(labelId: node.labelId) {
            #expect(kind == 1)
        }
        if let name = doc.dimTolName(labelId: node.labelId) {
            #expect(name == "Flatness")
        }
        if let desc = doc.dimTolDescription(labelId: node.labelId) {
            #expect(desc == "Surface flatness tolerance")
        }
        if let vals = doc.dimTolValues(labelId: node.labelId) {
            #expect(vals.count == 2)
            if vals.count >= 2 {
                #expect(abs(vals[0] - 0.01) < 1e-9)
                #expect(abs(vals[1] - 0.05) < 1e-9)
            }
        }
    }

    @Test func noDimTol() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(doc.dimTolKind(labelId: node.labelId) == nil)
    }
}
