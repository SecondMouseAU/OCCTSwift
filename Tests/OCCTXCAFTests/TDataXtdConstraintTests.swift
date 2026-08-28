import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd Constraint Tests")
struct TDataXtdConstraintTests {

    @Test func setAndGetType() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetType(labelId: node.labelId, type: .parallel)
        doc.commitTransaction()

        if let type = doc.constraintGetType(labelId: node.labelId) {
            #expect(type == .parallel)
        }
    }

    @Test func isPlanarAndDimension() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetType(labelId: node.labelId, type: .parallel)
        doc.commitTransaction()
        #expect(!doc.constraintIsPlanar(labelId: node.labelId))
        #expect(!doc.constraintIsDimension(labelId: node.labelId))
    }

    @Test func verifiedFlag() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setConstraint(labelId: node.labelId)
        doc.constraintSetVerified(labelId: node.labelId, verified: true)
        doc.commitTransaction()
        #expect(doc.constraintGetVerified(labelId: node.labelId))
    }

    @Test func noConstraint() {
        guard let doc = Document.create() else { return }
        guard let node = doc.createLabel() else { return }
        #expect(doc.constraintGetType(labelId: node.labelId) == nil)
    }
}
