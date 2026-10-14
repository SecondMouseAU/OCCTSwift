import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd Constraint Tests")
struct TDataXtdConstraintTests {

    @Test func setAndGetType() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetType(labelId: node.labelId, type: .parallel)
        doc.commitTransaction()

        let type = try #require(doc.constraintGetType(labelId: node.labelId))
        #expect(type == .parallel)
    }

    @Test func isPlanarAndDimension() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetType(labelId: node.labelId, type: .parallel)
        doc.commitTransaction()
        #expect(!doc.constraintIsPlanar(labelId: node.labelId))
        #expect(!doc.constraintIsDimension(labelId: node.labelId))
    }

    @Test func verifiedFlag() throws {
        let doc = try #require(Document.create())
        doc.openTransaction()
        let node = try #require(doc.createLabel())
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetVerified(labelId: node.labelId, verified: true)
        doc.commitTransaction()
        #expect(doc.constraintGetVerified(labelId: node.labelId))
    }

    @Test func noConstraint() throws {
        let doc = try #require(Document.create())
        let node = try #require(doc.createLabel())
        #expect(doc.constraintGetType(labelId: node.labelId) == nil)
    }
}
