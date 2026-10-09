import Foundation
import Testing

@testable import OCCTSwift

// #766: `selectSubShape` asserted a bare Bool, and `resolveShape` was a no-op
// (`if resolved != nil { #expect(Bool(true)) }`). Worse, the fixture had stopped meaning its own
// name: both tests built a standalone `Shape.face(from: Wire.rectangle(...))` and called it "a
// shape within context", when it is not a sub-shape of the box at all. The suite now selects a
// real face OF the box, and keeps the foreign-face case as its own test with the refusal it
// actually produces. Measured; see
// `Scripts/repro/766-xcaf-weak-assertions/probe-output.txt`.

@Suite("TNaming, Select and Resolve")
struct TNamingSelectResolveTests {

    /// Builds a box, records it as a primitive, and returns the document, the box, and one of
    /// its six faces.
    private func fixture() throws -> (Document, Shape, Shape, AssemblyNode) {
        let doc = try #require(Document.create())
        let contextLabel = try #require(doc.createLabel())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(doc.recordNaming(on: contextLabel, evolution: .primitive, newShape: box))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let face = try #require(faces.first)
        return (doc, box, face, contextLabel)
    }

    @Test("Selecting a real face of the context writes a selected evolution")
    func selectSubShape() throws {
        let (doc, box, face, _) = try fixture()
        let selectLabel = try #require(doc.createLabel())
        #expect(doc.namingEvolution(on: selectLabel) == nil)

        #expect(doc.selectShape(face, context: box, on: selectLabel))
        // The Bool is not the evidence; the attribute the selector wrote is.
        #expect(doc.namingEvolution(on: selectLabel) == .selected)
        #expect(!doc.namingIsEmpty(on: selectLabel))
    }

    /// Measured against OCCT 8.0.1: resolving a selection made against a bare primitive context
    /// returns a COMPOUND of all six faces of that context, area 600 for a 10-cube, not the
    /// single face that was selected.
    ///
    /// The old test asserted nothing at all here, so this records
    /// the kernel's actual answer. If a later OCCT or bridge change narrows the resolution to the
    /// selected face, this test fails deliberately and should be updated to the narrower answer.
    @Test("Resolving a selection returns the context faces, measured")
    func resolveShape() throws {
        let (doc, box, face, _) = try fixture()
        let selectLabel = try #require(doc.createLabel())
        #expect(doc.selectShape(face, context: box, on: selectLabel))

        let resolved = try #require(doc.resolveShape(on: selectLabel))
        #expect(resolved.shapeType == .compound)
        #expect(resolved.subShapes(ofType: .face).count == 6)
        let area = try #require(resolved.surfaceArea)
        #expect(abs(area - 599.999_999_999_999_9) < 1e-6)
        #expect(!resolved.isSame(as: box))
    }

    @Test("Resolving a label with no selection is a refusal")
    func resolveWithoutSelection() throws {
        let (doc, _, _, _) = try fixture()
        let bare = try #require(doc.createLabel())
        #expect(doc.resolveShape(on: bare) == nil)
        #expect(doc.namingEvolution(on: bare) == nil)
    }

    /// A face that is not a sub-shape of the context is accepted by `selectShape`, which returns
    /// true and writes a `.selected` evolution, but it resolves to nothing.
    ///
    /// This is the fixture the whole suite used to run on, which is why every assertion in it
    /// was vacuous.
    @Test("A face foreign to the context selects but does not resolve")
    func selectForeignFace() throws {
        let (doc, box, _, _) = try fixture()
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let foreignFace = try #require(Shape.face(from: wire))
        let selectLabel = try #require(doc.createLabel())

        #expect(doc.selectShape(foreignFace, context: box, on: selectLabel))
        #expect(doc.namingEvolution(on: selectLabel) == .selected)
        #expect(doc.resolveShape(on: selectLabel) == nil)
    }

    @Test("Selected evolution type")
    func selectedEvolution() throws {
        let (doc, box, face, _) = try fixture()
        let selectLabel = try #require(doc.createLabel())
        #expect(doc.selectShape(face, context: box, on: selectLabel))
        #expect(doc.namingEvolution(on: selectLabel) == .selected)
    }
}
