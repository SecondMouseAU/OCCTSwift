import Foundation
import Testing

@testable import OCCTSwift

@Suite("DocumentExplorer Extension Tests")
struct DocumentExplorerExtensionTests {

    // #766: this used to be `#expect(depth >= 0)` inside `if count > 0`, which is true of every
    // Int32 the walk could return, and also of the 0 the bridge hands back for an index outside
    // the explorer's range. The flat case alone cannot distinguish a working depth from a
    // hardcoded 0, so the assembly case below supplies the non-zero answer. Measured; see
    // `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.
    @Test func explorerDepth() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = doc.addShape(box)
        #expect(doc.explorerNodeCount == 1)
        #expect(doc.explorerDepth(at: 0) == 0, "a free shape with no parent is at depth 0")
    }

    @Test func explorerDepthUnderAnAssemblyIsOne() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let part = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let partLabelId = doc.addShape(part, makeAssembly: false)
        let assemblyLabelId = doc.newShapeLabel()
        #expect(
            doc.addComponent(
                assemblyLabelId: assemblyLabelId, shapeLabelId: partLabelId,
                translation: (5, 0, 0)) >= 0)
        doc.updateAssemblies()

        // The part is now instantiated one level under the assembly, and the leaf-only walk
        // reports that level. A depth stuck at 0 fails here.
        #expect(doc.explorerNodeCount == 1)
        #expect(doc.explorerDepth(at: 0) == 1)
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
