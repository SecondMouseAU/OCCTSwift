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

    // #1480: explorerIsAssembly shares its flat index with explorerShape/explorerDepth/
    // explorerLocation, all built by walking XCAFPrs_DocumentExplorer with
    // XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, which OCCT's own header documents as
    // skipping assembly nodes. So no index reachable through this explorer can ever be an
    // assembly node, structurally, by design: this proves that against a REAL assembly
    // (unlike the plain-box case above, which never had an assembly to miss), confirmed via
    // the real accessor, AssemblyNode.isAssembly, which walks the free-shape/component label
    // tree directly rather than this leaf-only list.
    @Test func explorerIsAssemblyNeverTrueEvenForARealAssembly() {
        guard let doc = Document.create(),
            let part = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("no doc/box")
            return
        }
        doc.defineAllFormats()
        let partLabelId = doc.addShape(part, makeAssembly: false)
        let assemblyLabelId = doc.newShapeLabel()
        #expect(
            doc.addComponent(
                assemblyLabelId: assemblyLabelId, shapeLabelId: partLabelId,
                translation: (5, 0, 0)) >= 0)
        doc.updateAssemblies()

        // Confirm this really is an assembly, via the accessor that can actually see it.
        guard let assemblyNode = doc.node(at: assemblyLabelId) else {
            Issue.record("no assembly node")
            return
        }
        #expect(assemblyNode.isAssembly)

        // Every node the flat leaf-only explorer can walk to, including the leaf part
        // instantiated under this real assembly, still reports false.
        let count = doc.explorerNodeCount
        #expect(count > 0)
        for i in 0..<count {
            #expect(!doc.explorerIsAssembly(at: i))
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

    // #1480: OCCTDocumentExplorerLocation pre-fills matrix12 with an "identity" fallback
    // BEFORE the try block, so any index outside the explorer's real range never overwrites
    // it and the function returns that fallback untouched. The formula used to be
    // `(i % 4 == i / 3) ? 1.0 : 0.0`, which sets 1.0 at indices 0, 5, 6, 11 (not the diagonal
    // 0, 5, 10 a row-major 3x4 identity needs), corrupting row 3 with a bogus translation and
    // zero rotation weight. Force that fallback path with an out-of-range index and assert a
    // genuine identity comes back.
    @Test func explorerLocationOutOfRangeIndexIsATrueIdentity() {
        guard let doc = Document.create() else { return }
        doc.defineAllFormats()
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            _ = doc.addShape(box)
        }
        let count = doc.explorerNodeCount
        // Any index >= count never matches inside the walk, forcing the pre-filled fallback.
        let matrix = doc.explorerLocation(at: count + 100)
        let expectedIdentity: [Double] = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
        ]
        #expect(matrix == expectedIdentity)
    }
}
