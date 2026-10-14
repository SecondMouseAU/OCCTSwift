import Foundation
import Testing

@testable import OCCTSwift

@Suite("TNaming Scope Tests")
struct TNamingScopeTests {

    @Test func validAndIsValid() throws {
        let doc = try #require(Document.create())
        doc.namingScopeClear()
        let node = try #require(doc.createLabel())
        doc.namingScopeValid(labelId: node.labelId)
        #expect(doc.namingScopeIsValid(labelId: node.labelId))
    }

    @Test func unvalid() throws {
        let doc = try #require(Document.create())
        doc.namingScopeClear()
        let node = try #require(doc.createLabel())
        doc.namingScopeValid(labelId: node.labelId)
        doc.namingScopeUnvalid(labelId: node.labelId)
        #expect(!doc.namingScopeIsValid(labelId: node.labelId))
    }

    @Test func validCount() throws {
        let doc = try #require(Document.create())
        doc.namingScopeClear()
        let n1 = try #require(doc.createLabel())
        let n2 = try #require(doc.createLabel())
        doc.namingScopeValid(labelId: n1.labelId)
        doc.namingScopeValid(labelId: n2.labelId)
        #expect(doc.namingScopeValidCount >= 2)
        doc.namingScopeClear()
        #expect(doc.namingScopeValidCount == 0)
    }
}
