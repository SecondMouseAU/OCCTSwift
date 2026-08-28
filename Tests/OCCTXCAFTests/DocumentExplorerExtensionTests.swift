import Foundation
import Testing

@testable import OCCTSwift

@Suite("DocumentExplorer Extension Tests")
struct DocumentExplorerExtensionTests {

    @Test func explorerDepth() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            if count > 0 {
                let depth = doc.explorerDepth(at: 0)
                #expect(depth >= 0)
            }
        }
    }

    @Test func explorerIsAssembly() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            if count > 0 {
                // A single shape is not an assembly
                let isAsm = doc.explorerIsAssembly(at: 0)
                #expect(!isAsm)
            }
        }
    }

    @Test func explorerLocation() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
            let count = doc.explorerNodeCount
            if count > 0 {
                let matrix = doc.explorerLocation(at: 0)
                #expect(matrix.count == 12)
            }
        }
    }
}
