import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming Scope Tests")
struct TNamingScopeTests {

    @Test func validAndIsValid() {
        guard let doc = Document.create() else { return }
        doc.namingScopeClear()
        guard let node = doc.createLabel() else { return }
        doc.namingScopeValid(labelId: node.labelId)
        #expect(doc.namingScopeIsValid(labelId: node.labelId))
    }

    @Test func unvalid() {
        guard let doc = Document.create() else { return }
        doc.namingScopeClear()
        guard let node = doc.createLabel() else { return }
        doc.namingScopeValid(labelId: node.labelId)
        doc.namingScopeUnvalid(labelId: node.labelId)
        #expect(!doc.namingScopeIsValid(labelId: node.labelId))
    }

    @Test func validCount() {
        guard let doc = Document.create() else { return }
        doc.namingScopeClear()
        guard let n1 = doc.createLabel(), let n2 = doc.createLabel() else { return }
        doc.namingScopeValid(labelId: n1.labelId)
        doc.namingScopeValid(labelId: n2.labelId)
        #expect(doc.namingScopeValidCount >= 2)
        doc.namingScopeClear()
        #expect(doc.namingScopeValidCount == 0)
    }
}
