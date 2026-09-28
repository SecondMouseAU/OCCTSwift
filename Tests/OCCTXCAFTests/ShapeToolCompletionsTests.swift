import Foundation
import Testing

@testable import OCCTSwift

/// The `XCAFDoc_ShapeTool` predicates and counters, pinned to measured kernel values.
///
/// Every value asserted below was measured by the ground-truth probe in
/// `Scripts/repro/766-xcaf-shape-tool-completions/`, which calls the same `XCAFDoc_ShapeTool`
/// entry points the bridge calls, on the same input (a 10x10x10 box centred on the origin, added
/// with `AddShape(shape, makeAssembly = true)`), and prints what the kernel returns:
///
///     IsFree=true IsSimpleShape=true IsComponent=false IsCompound=false
///     IsSubShape=false IsExternRef=false
///     GetUsers=0 NbComponents=0
///     ComputeShapes returned; IsFree still=true
@Suite("v0.126.0, XCAFDoc_ShapeTool completions")
struct ShapeToolCompletionsTests {
    /// The document, box and label every test in this suite measures.
    ///
    /// Held as a value so the `Document` and the `Shape` outlive the label id, which is only
    /// meaningful while the document that issued it is alive.
    private struct Fixture {
        let doc: Document
        let box: Shape
        let labelId: Int64
    }

    /// Builds the probe's input and proves it was built, with no silent escape.
    ///
    /// Each step is a `try #require`, not a `guard let ... else { return }` or an `if let`. Until
    /// #2794 all nine tests in this suite opened with the same three-deep escape chain (`guard let
    /// doc`, `if let box`, `if labelId >= 0`), so any regression that stopped a document, a box or
    /// a label from being created made all nine pass having executed no expectation at all.
    ///
    /// The `findShape` step is the control, and it is the reason the negative assertions below
    /// mean anything. Six of the nine subjects are asserted to be `false` or `0`, and `false` and
    /// `0` are also what the bridge returns for a label it cannot resolve
    /// (`OCCTBridge_Modeling_Misc.mm`, every one of these functions answers its `lab.IsNull()`
    /// branch that way). Without independent proof that this label exists and holds this box, a
    /// label that is not there at all satisfies them.
    private func measuredBoxLabel() throws -> Fixture {
        let doc = try #require(Document.create(), "Document.create() returned nil")
        let box = try #require(
            Shape.box(width: 10, height: 10, depth: 10), "Shape.box returned nil")
        let labelId = doc.addShape(box)
        try #require(labelId >= 0, "addShape refused the box, it returned \(labelId)")
        let resolvedId = doc.findShape(box)
        try #require(
            resolvedId == labelId,
            "findShape resolves the box to \(resolvedId), not the \(labelId) addShape returned")
        return Fixture(doc: doc, box: box, labelId: labelId)
    }

    @Test("IsFree is true for a top-level shape")
    func isFree() throws {
        let f = try measuredBoxLabel()
        #expect(f.doc.shapeToolIsFree(labelId: f.labelId))
    }

    @Test("IsSimpleShape is true for a box")
    func isSimpleShape() throws {
        let f = try measuredBoxLabel()
        #expect(f.doc.shapeToolIsSimpleShape(labelId: f.labelId))
    }

    @Test("IsComponent is false for a simple shape")
    func isComponent() throws {
        let f = try measuredBoxLabel()
        #expect(!f.doc.shapeToolIsComponent(labelId: f.labelId))
    }

    @Test("IsCompound is false for a simple box")
    func isCompound() throws {
        let f = try measuredBoxLabel()
        #expect(!f.doc.shapeToolIsCompound(labelId: f.labelId))
    }

    @Test("IsSubShape is false for a top-level label")
    func isSubShape() throws {
        let f = try measuredBoxLabel()
        #expect(!f.doc.shapeToolIsSubShape(labelId: f.labelId))
    }

    @Test("IsExternRef is false for a regular shape")
    func isExternRef() throws {
        let f = try measuredBoxLabel()
        #expect(!f.doc.shapeToolIsExternRef(labelId: f.labelId))
    }

    @Test("GetUsers is 0 for an unreferenced shape")
    func getUsers() throws {
        let f = try measuredBoxLabel()
        #expect(f.doc.shapeToolGetUsers(labelId: f.labelId) == 0)
    }

    @Test("NbComponents is 0 for a simple shape, with and without sub-children")
    func nbComponents() throws {
        let f = try measuredBoxLabel()
        #expect(f.doc.shapeToolNbComponents(labelId: f.labelId) == 0)
        #expect(f.doc.shapeToolNbComponents(labelId: f.labelId, getSubChildren: true) == 0)
    }

    /// ComputeShapes returns a `void` the bridge cannot fail, so the assertion is on the state
    /// afterwards, which is the third line the probe prints: the call returns and the label is
    /// still the box's free, component-less label.
    ///
    /// The suite's earlier form asserted nothing here and said so in a comment ("Just check it
    /// doesn't crash"), which made a crash the only failure the test could report.
    @Test("ComputeShapes leaves the label intact, IsFree still true")
    func computeShapes() throws {
        let f = try measuredBoxLabel()
        f.doc.shapeToolComputeShapes(labelId: f.labelId)
        #expect(f.doc.shapeToolIsFree(labelId: f.labelId))
        #expect(f.doc.findShape(f.box) == f.labelId)
        #expect(f.doc.shapeToolNbComponents(labelId: f.labelId) == 0)
    }
}
