import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1009: the GROUPED 12-double reader was three byte-identical copies of the same permuted
/// `gp_Trsf::SetValues`, in `OCCTBridge_Curve3D.mm`, `OCCTBridge_Document.mm` and
/// `OCCTBridge_Modeling.mm`. All three now call `occtTrsfFromMatrix12Grouped` in
/// `OCCTBridge_Internal.h`, next to #994's INTERLEAVED sibling.
///
/// The two layouts must never share a reader, and every case below is chosen so that reading the
/// same array with the INTERLEAVED one gives a different, wrong, silently accepted answer:
/// translation `(0, 0, 7)` instead of `(5, 6, 7)`, and a parametric factor of `0` instead of `2`.
/// This suite spans three domains, so it sits in `OCCTMiscTests` rather than picking one of them.
@Suite("One GROUPED 12-double reader, shared by all three call sites (#1009)")
struct Issue1009Matrix12Grouped {

    /// Identity rotation, translate by (5, 6, 7). Read INTERLEAVED this is translation (0, 0, 7).
    private static let translate567: [Double] = [
        1, 0, 0,
        0, 1, 0,
        0, 0, 1,
        5, 6, 7,
    ]

    /// A 30-degree rotation about Z with the same translation, so no two of the twelve slots hold
    /// the same number and a permuted read cannot agree by coincidence.
    private static let rotatedAndTranslated: [Double] = {
        let c = cos(Double.pi / 6)
        let s = sin(Double.pi / 6)
        return [
            c, -s, 0,
            s, c, 0,
            0, 0, 1,
            5, 6, 7,
        ]
    }()

    private func makeBox() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)
    }

    // MARK: - OCCTShapeTransformed

    @Test("Shape.transformed(matrix:) moves the shape by the GROUPED translation")
    func shapeTransformedAppliesTheGroupedTranslation() throws {
        let box = try #require(makeBox())
        let before = try #require(box.boundingBox)
        let matrix = try #require(Matrix12Grouped(Self.translate567))
        let moved = try #require(box.transformed(matrix: matrix))
        let after = try #require(moved.boundingBox)

        // Exactly (5, 6, 7). Reading the array INTERLEAVED gives (0, 0, 7), and dropping the
        // translation gives (0, 0, 0).
        #expect(abs((after.min.x - before.min.x) - 5) < 1e-9)
        #expect(abs((after.min.y - before.min.y) - 6) < 1e-9)
        #expect(abs((after.min.z - before.min.z) - 7) < 1e-9)
        #expect(abs((after.max.x - before.max.x) - 5) < 1e-9)
        #expect(abs((after.max.y - before.max.y) - 6) < 1e-9)
        #expect(abs((after.max.z - before.max.z) - 7) < 1e-9)
    }

    @Test("A GROUPED matrix agrees with the same transform written INTERLEAVED")
    func groupedAgreesWithItsInterleavedConversion() throws {
        let box = try #require(makeBox())
        let grouped = try #require(Matrix12Grouped(Self.rotatedAndTranslated))

        // A second construction through a different bridge function: transformed(byMatrix:) goes to
        // OCCTShapeTransformedBy..., which takes the twelve doubles positionally rather than
        // permuting them, so agreement here is evidence about the permutation and not about one
        // shared code path.
        let viaGrouped = try #require(box.transformed(matrix: grouped))
        let viaInterleaved = try #require(box.transformed(byMatrix: grouped.interleaved))

        let a = try #require(viaGrouped.boundingBox)
        let b = try #require(viaInterleaved.boundingBox)
        #expect(abs(a.min.x - b.min.x) < 1e-9)
        #expect(abs(a.min.y - b.min.y) < 1e-9)
        #expect(abs(a.min.z - b.min.z) < 1e-9)
        #expect(abs(a.max.x - b.max.x) < 1e-9)
        #expect(abs(a.max.y - b.max.y) < 1e-9)
        #expect(abs(a.max.z - b.max.z) < 1e-9)

        // And the rotation did something, so the two are not agreeing on an untransformed shape.
        let before = try #require(box.boundingBox)
        #expect(abs(a.min.x - (before.min.x + 5)) > 1e-6)
    }

    // MARK: - OCCTCurve3DParametricTransformation

    @Test("Curve3D.parametricTransformation reads the rotation from the GROUPED slots")
    func curve3dParametricTransformationReadsTheGroupedLayout() throws {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))

        // A line's parameter is arc length from its origin point, so a uniform scale of k maps the
        // parameter by k. Measured against the pinned kernel in
        // Scripts/repro/1009-matrix12-grouped/: 2 through the GROUPED reader, 0 through the
        // INTERLEAVED one, which turns the same array into a rank-deficient matrix.
        let scale2 = line.parametricTransformation(
            rotation: [2, 0, 0, 0, 2, 0, 0, 0, 2], translation: SIMD3(1, 2, 3))
        #expect(abs(scale2 - 2) < 1e-9)

        // A pure translation leaves the parameterisation alone.
        let translated = line.parametricTransformation(
            rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1], translation: SIMD3(5, 6, 7))
        #expect(abs(translated - 1) < 1e-9)

        // The scale factor 1.0 is also the bridge's error sentinel (null handle, exception, bad
        // rotation count). A second discriminator: the same translation matrix, applied to a wire
        // made from the line, must actually move the wire by (5, 6, 7).
        let wire = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0)))
        let shape = try #require(Shape.fromWire(wire))
        let matrix = try #require(
            Matrix12Grouped([
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
                5, 6, 7,
            ]))
        let moved = try #require(shape.transformed(matrix: matrix))
        let beforeBB = try #require(shape.boundingBox)
        let afterBB = try #require(moved.boundingBox)
        #expect(abs((afterBB.min.x - beforeBB.min.x) - 5) < 1e-9)
        #expect(abs((afterBB.min.y - beforeBB.min.y) - 6) < 1e-9)
        #expect(abs((afterBB.min.z - beforeBB.min.z) - 7) < 1e-9)
    }

    // MARK: - OCCTDocumentAddComponentMatrix

    @Test("Document.addComponent(matrix:) places the component at the GROUPED translation")
    func documentAddComponentReadsTheGroupedLayout() throws {
        let doc = try #require(Document.create())
        let box = try #require(makeBox())
        let partId = doc.addShape(box, makeAssembly: false)
        let assemblyId = doc.newShapeLabel()
        let componentId = doc.addComponent(
            assemblyLabelId: assemblyId, shapeLabelId: partId, matrix: Self.translate567)
        try #require(componentId >= 0)
        doc.updateAssemblies()

        let placed = try #require(AssemblyNode(document: doc, labelId: componentId).shape)
        let after = try #require(placed.boundingBox)
        let before = try #require(box.boundingBox)
        #expect(abs((after.min.x - before.min.x) - 5) < 1e-9)
        #expect(abs((after.min.y - before.min.y) - 6) < 1e-9)
        #expect(abs((after.min.z - before.min.z) - 7) < 1e-9)
    }

    @Test("Document.addComponent(matrix:) accepts a reflection and actually reflects")
    func documentAddComponentAcceptsAReflection() throws {
        // The doc comment on this method used to say a reflection is rejected, and the bridge
        // comment said gp_Trsf::SetValues throws for anything that is not a proper rigid transform.
        // Measured, SetValues refuses nothing here: its own header names a null determinant as the
        // single precondition, not orthonormality, and it is Standard_EXPORT, compiled inside
        // OCCT's Release TUs where No_Exception removes even that.
        let doc = try #require(Document.create())
        let box = try #require(Shape.box(origin: SIMD3(1, 0, 0), width: 10, height: 10, depth: 10))
        let partId = doc.addShape(box, makeAssembly: false)
        let assemblyId = doc.newShapeLabel()
        let mirrorInX: [Double] = [
            -1, 0, 0,
            0, 1, 0,
            0, 0, 1,
            0, 0, 0,
        ]
        let componentId = doc.addComponent(
            assemblyLabelId: assemblyId, shapeLabelId: partId, matrix: mirrorInX)
        #expect(componentId >= 0)
        doc.updateAssemblies()

        let placed = try #require(AssemblyNode(document: doc, labelId: componentId).shape)
        let after = try #require(placed.boundingBox)
        // The box spanned x in [1, 11]; mirrored in X it spans [-11, -1].
        #expect(abs(after.min.x - -11) < 1e-6)
        #expect(abs(after.max.x - -1) < 1e-6)
    }
}
