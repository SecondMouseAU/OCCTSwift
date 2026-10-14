import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd PatternStd Tests")
struct TDataXtdPatternStdTests {

    @Test func setAndGetSignature() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.setPattern(labelId: node.labelId)
        doc.patternSetSignature(labelId: node.labelId, signature: .linear)
        doc.commitTransaction()

        let sig = try #require(doc.patternGetSignature(labelId: node.labelId))
        #expect(sig == .linear)
    }

    @Test func hasPattern() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.setPattern(labelId: node.labelId)
        doc.commitTransaction()
        #expect(doc.hasPattern(labelId: node.labelId))
    }

    @Test func noPattern() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        #expect(!doc.hasPattern(labelId: node.labelId))
    }
}
