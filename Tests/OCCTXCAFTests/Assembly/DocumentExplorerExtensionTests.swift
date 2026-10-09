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

    @Test func explorerIsAssembly() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxLabelId = doc.addShape(box)
        // Exactly one node in the walk, so the loop below is over a real node and not over none.
        #expect(doc.explorerNodeCount == 1)
        // A single shape is not an assembly
        #expect(!doc.explorerIsAssembly(at: 0))
        // Same answer from the accessor that reads the label tree, and an index past the walk
        // is not an assembly either.
        let node = try #require(doc.node(at: boxLabelId))
        #expect(!node.isAssembly)
        #expect(!doc.explorerIsAssembly(at: 1))
        #expect(!doc.explorerIsAssembly(at: -1))
    }

    // #1480: explorerIsAssembly shares its flat index with explorerShape/explorerDepth/
    // explorerLocation, all built by walking XCAFPrs_DocumentExplorer with
    // XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, which OCCT's own header documents as
    // skipping assembly nodes. So no index reachable through this explorer can ever be an
    // assembly node, structurally, by design: this proves that against a REAL assembly
    // (unlike the plain-box case above, which never had an assembly to miss), confirmed via
    // the real accessor, AssemblyNode.isAssembly, which walks the free-shape/component label
    // tree directly rather than this leaf-only list.
    @Test func explorerIsAssemblyNeverTrueEvenForARealAssembly() throws {
        let doc = try #require(Document.create())
        let part = try #require(Shape.box(width: 10, height: 10, depth: 10))
        doc.defineAllFormats()
        let partLabelId = doc.addShape(part, makeAssembly: false)
        let assemblyLabelId = doc.newShapeLabel()
        #expect(
            doc.addComponent(
                assemblyLabelId: assemblyLabelId, shapeLabelId: partLabelId,
                translation: (5, 0, 0)) >= 0)
        doc.updateAssemblies()

        // Confirm this really is an assembly, via the accessor that can actually see it, and
        // that the part is not one: the control that makes the `false` below a reading.
        let assemblyNode = try #require(doc.node(at: assemblyLabelId), "no assembly node")
        #expect(assemblyNode.isAssembly)
        let partNode = try #require(doc.node(at: partLabelId), "no part node")
        #expect(!partNode.isAssembly)

        // Every node the flat leaf-only explorer can walk to, including the leaf part
        // instantiated under this real assembly, still reports false. There is exactly one such
        // node (the part), so the loop is over that one and not over an empty range.
        let count = doc.explorerNodeCount
        #expect(count == 1)
        for i in 0..<count {
            #expect(!doc.explorerIsAssembly(at: i))
        }
        #expect(!doc.explorerIsAssembly(at: count))
    }

    /// The explorer's location is the occurrence's placement as a row-major 3x4.
    ///
    /// The rotation rows are each followed by the translation,
    /// `[r00 r01 r02 tx, r10 r11 r12 ty, r20 r21 r22 tz]`.
    /// Every expected matrix below is written from the placement given to `addComponent`, not
    /// read back from the explorer.
    @Test func explorerLocation() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = doc.addShape(box)
        #expect(doc.explorerNodeCount == 1)
        // A free shape sits at the identity.
        #expect(doc.explorerLocation(at: 0) == [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0])

        // Under an assembly, at a translation with a different value on each axis, and then at
        // a rotation: 90 degrees about Z plus a translation, and a mirror in X plus one.
        let doc2 = try #require(Document.create())
        doc2.defineAllFormats()
        let part = doc2.addShape(box, makeAssembly: false)
        let asm = doc2.newShapeLabel()
        let rigid: [Double] = [0, -1, 0, 1, 0, 0, 0, 0, 1, 10, 20, 30]
        let reflect: [Double] = [-1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0]
        #expect(doc2.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: rigid) >= 0)
        #expect(doc2.addComponent(assemblyLabelId: asm, shapeLabelId: part, matrix: reflect) >= 0)
        doc2.updateAssemblies()
        #expect(doc2.explorerNodeCount == 2)
        // The grouped input `[r00 r01 r02 r10 r11 r12 r20 r21 r22 tx ty tz]` read as rows with
        // the translation moved to the fourth column.
        #expect(doc2.explorerLocation(at: 0) == [0, -1, 0, 10, 1, 0, 0, 20, 0, 0, 1, 30])
        #expect(doc2.explorerLocation(at: 1) == [-1, 0, 0, 5, 0, 1, 0, 0, 0, 0, 1, 0])

        let doc3 = try #require(Document.create())
        doc3.defineAllFormats()
        let part3 = doc3.addShape(box, makeAssembly: false)
        let asm3 = doc3.newShapeLabel()
        #expect(
            doc3.addComponent(
                assemblyLabelId: asm3, shapeLabelId: part3, translation: (3, 4, 5)) >= 0)
        doc3.updateAssemblies()
        #expect(doc3.explorerLocation(at: 0) == [1, 0, 0, 3, 0, 1, 0, 4, 0, 0, 1, 5])
    }

    // #1480: OCCTDocumentExplorerLocation pre-fills matrix12 with an "identity" fallback
    // BEFORE the try block, so any index outside the explorer's real range never overwrites
    // it and the function returns that fallback untouched. The formula used to be
    // `(i % 4 == i / 3) ? 1.0 : 0.0`, which sets 1.0 at indices 0, 5, 6, 11 (not the diagonal
    // 0, 5, 10 a row-major 3x4 identity needs), corrupting row 3 with a bogus translation and
    // zero rotation weight. Force that fallback path with an out-of-range index and assert a
    // genuine identity comes back.
    @Test func explorerLocationOutOfRangeIndexIsATrueIdentity() throws {
        let doc = try #require(Document.create())
        doc.defineAllFormats()
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let part = doc.addShape(box, makeAssembly: false)
        let asm = doc.newShapeLabel()
        // A placed part, so the identity below is not the answer for a document whose only
        // occurrence happens to sit at the identity.
        #expect(
            doc.addComponent(assemblyLabelId: asm, shapeLabelId: part, translation: (5, 0, 0)) >= 0)
        doc.updateAssemblies()
        let count = doc.explorerNodeCount
        #expect(count == 1)
        #expect(doc.explorerLocation(at: 0) == [1, 0, 0, 5, 0, 1, 0, 0, 0, 0, 1, 0])

        let expectedIdentity: [Double] = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
        ]
        // Any index >= count never matches inside the walk, forcing the pre-filled fallback.
        #expect(doc.explorerLocation(at: count) == expectedIdentity)
        #expect(doc.explorerLocation(at: count + 100) == expectedIdentity)
        #expect(doc.explorerLocation(at: -1) == expectedIdentity)

        // And on a document with no shapes at all.
        let empty = try #require(Document.create())
        empty.defineAllFormats()
        #expect(empty.explorerNodeCount == 0)
        #expect(empty.explorerLocation(at: 0) == expectedIdentity)
    }
}
