import Foundation
import Testing

@testable import OCCTSwift

@Suite("Document Materials")
struct DocumentMaterialTests {
    @Test("Empty document has no materials")
    func emptyMaterials() throws {
        let doc = try #require(Document.create())
        #expect(doc.materialCount == 0)
        #expect(doc.materials.isEmpty)
    }

    @Test("Material info out of range returns nil")
    func outOfRange() throws {
        let doc = try #require(Document.create())
        #expect(doc.materialInfo(at: 0) == nil)
    }
}
