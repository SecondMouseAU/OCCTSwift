import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFPrs_DocumentExplorer Tests")
struct DocumentExplorerTests {

    @Test func exploreDocumentWithShape() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            #expect(count >= 1)
        }
    }

    @Test func explorerShapeAtIndex() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let shape = doc.explorerShape(at: 0)
            #expect(shape != nil)
        }
    }

    @Test func explorerPathId() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let pathId = doc.explorerPathId(at: 0)
            #expect(pathId != nil)
        }
    }

    @Test func findShapeFromPathId() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            if let pathId = doc.explorerPathId(at: 0) {
                let found = doc.explorerFindShape(pathId: pathId)
                #expect(found != nil)
            }
        }
    }
}
