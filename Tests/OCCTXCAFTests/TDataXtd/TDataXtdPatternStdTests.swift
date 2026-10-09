import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd PatternStd Tests")
struct TDataXtdPatternStdTests {

    @Test func setAndGetSignature() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPattern(labelId: node.labelId)
        doc.patternSetSignature(labelId: node.labelId, signature: .linear)
        doc.commitTransaction()

        if let sig = doc.patternGetSignature(labelId: node.labelId) {
            #expect(sig == .linear)
        }
    }

    @Test func hasPattern() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPattern(labelId: node.labelId)
        doc.commitTransaction()
        #expect(doc.hasPattern(labelId: node.labelId))
    }

    @Test func noPattern() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(!doc.hasPattern(labelId: node.labelId))
    }
}
