import Foundation
import Testing

@testable import OCCTSwift

/// #1026: `Shape.nullified` returns a `Shape` wrapping a null `TopoDS_Shape`, and forty-two
/// bridge functions read something off a caller-supplied shape with no `IsNull()` test on that
/// shape.
///
/// `TopoDS_Shape::ShapeType()` is a bare `myTShape->ShapeType()` (`TopoDS_Shape.hxx:140`), and
/// `TopoDS_TShape::ShapeType()` is a plain member read of the packed state word
/// (`TopoDS_TShape.hxx:144`), not a virtual call. So each one loaded from the offset of `myState`
/// inside the zero page: a SIGSEGV at address 0x38, which the `catch (...)` most of them carry
/// cannot absorb.
///
/// Ten of the `ShapeType()` readers are reachable from public Swift with a nullified shape, and
/// this suite covers all ten. Five more take an `Edge` or a `Face`, and no public producer of
/// either hands back one wrapping a null topology; `edgeAndFaceRefuseANullifiedShape` measures
/// that rather than asserting it, so a future producer that stops guarding shows up here.
///
/// `ShapeType()` is not the whole class. `TopoDS_Shape`'s eight flag accessors dereference
/// `myTShape` the same way, and ten further bridge sites read or write them; all ten were
/// measured crashing on the same input and are covered here too.
///
/// `Scripts/repro/1026-null-shape-type-guard/` carries the pre-fix transcripts, including the
/// faulting address, and the guard-removal matrix.
@Suite("A nullified shape answers every type query instead of crashing (#1026)")
struct Issue1026NullShapeTypeGuard {

    private func makeBox() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    private func makeNullShape() throws -> Shape {
        try #require(try makeBox().nullified)
    }

    // MARK: - The ten reachable reads, each of which was a SIGSEGV

    @Test("shapeType of a nullified shape is .unknown, not a crash")
    func shapeTypeOfANullifiedShapeIsUnknown() throws {
        #expect(try makeNullShape().shapeType == .unknown)
    }

    @Test("isValidSolid of a nullified shape is false, not a crash")
    func isValidSolidOfANullifiedShapeIsFalse() throws {
        #expect(try makeNullShape().isValidSolid == false)
    }

    @Test("All five type predicates are false for a nullified shape")
    func theFiveTypePredicatesAreFalseForANullifiedShape() throws {
        let nullShape = try makeNullShape()
        #expect(nullShape.isCompound == false)
        #expect(nullShape.isSolid == false)
        #expect(nullShape.isShell == false)
        #expect(nullShape.isFace == false)
        #expect(nullShape.isEdge == false)
    }

    @Test("shapeTypeString of a nullified shape reads \"null\", not a crash")
    func shapeTypeStringOfANullifiedShapeReadsNull() throws {
        #expect(try makeNullShape().shapeTypeString == "null")
    }

    @Test("typeName of a nullified shape is nil, as its doc comment already promised")
    func typeNameOfANullifiedShapeIsNil() throws {
        #expect(try makeNullShape().typeName == nil)
    }

    @Test("intersectLine against a nullified shape finds nothing, not a crash")
    func intersectLineWithANullifiedShapeFindsNothing() throws {
        let hits = try makeNullShape().intersectLine(
            origin: SIMD3(0, 0, -50), direction: SIMD3(0, 0, 1), paramRange: -1000...1000)
        #expect(hits.isEmpty)
    }

    // MARK: - The nine flag accessors, the half of the class the issue's census did not key on

    /// The eight flag accessors crash the same way `ShapeType()` does.
    ///
    /// `TopoDS_Shape`'s `Free`, `Locked`, `Modified`, `Checked`, `Orientable`, `Closed`,
    /// `Infinite` and `Convex` read and write the same packed state word through the same
    /// unguarded `myTShape` dereference (`TopoDS_Shape.hxx:143-188`), so all nine bridge sites
    /// crashed identically.
    ///
    /// `theFlagAccessorsStillAnswerForARealShape` is what makes the all-false row below mean
    /// something: five of the eight flags are measured `true` on some sub-shape of a plain box,
    /// so `false` here is a refusal rather than the answer a real shape would have given anyway.
    @Test("All eight flag getters are false for a nullified shape, and the setter is a no-op")
    func theFlagAccessorsRefuseANullifiedShape() throws {
        let nullShape = try makeNullShape()
        #expect(nullShape.isFree == false)
        #expect(nullShape.isModified == false)
        #expect(nullShape.isChecked == false)
        #expect(nullShape.isOrientable == false)
        #expect(nullShape.isInfinite == false)
        #expect(nullShape.isConvex == false)
        #expect(nullShape.isLocked == false)
        #expect(nullShape.isClosedShape == false)

        nullShape.setLocked(true)
        #expect(nullShape.isLocked == false)
    }

    /// The positive controls, measured rather than derived.
    ///
    /// A solid answers `Free` and `Modified` true but `Orientable` FALSE, which the first draft of
    /// this test got wrong by reading `TopoDS_TShape`'s constructor's initial bit set instead of
    /// asking the shape. `Infinite` and `Convex` are false on every sub-shape of a box, so those
    /// two are the row's two flags with no positive control here, and this comment says so rather
    /// than letting the green count imply otherwise.
    @Test("The flag getters still report a real shape's own flags")
    func theFlagAccessorsStillAnswerForARealShape() throws {
        let box = try makeBox()
        #expect(box.isFree == true)
        #expect(box.isModified == true)

        let shells = box.subShapes(ofType: .shell)
        let faces = box.subShapes(ofType: .face)
        try #require(!shells.isEmpty)
        try #require(!faces.isEmpty)
        #expect(shells[0].isOrientable == true)
        #expect(shells[0].isClosedShape == true)
        #expect(faces[0].isChecked == true)

        #expect(box.isLocked == false)
        box.setLocked(true)
        #expect(box.isLocked == true)
        box.setLocked(false)
        #expect(box.isLocked == false)
    }

    // MARK: - The nineteen sites the taught gate found that no census had listed

    /// The sites the taught gate found, which no hand-built census had listed.
    ///
    /// The issue named fifteen `ShapeType()` readers; `check-null-handle-guards.py`'s third walk
    /// found nineteen it did not, across five files, and every one is the same unguarded
    /// `myTShape` dereference. Seven of the nineteen were hidden by an `IsNull()` on a different
    /// subject, the rest by a local copy or a reference alias. These are the ones with a public
    /// Swift face that takes a `Shape`, so a nullified shape reaches them the same way.
    @Test("The sites the taught gate found refuse a nullified shape rather than crashing")
    func theGateFoundSitesRefuseANullifiedShape() throws {
        let box = try makeBox()
        let nullShape = try makeNullShape()

        #expect(LengthDimension(edge: nullShape) == nil)
        #expect(LengthDimension(face1: nullShape, face2: nullShape) == nil)
        #expect(AngleDimension(edge1: nullShape, edge2: nullShape) == nil)
        #expect(AngleDimension(face1: nullShape, face2: nullShape) == nil)

        #expect(nullShape.upgraded() == nil)
        #expect(nullShape.connectedFaces() == nil)
        #expect(Shape.solidFromShell(nullShape) == nil)
        #expect(box.splitByWireOnFace(nullShape, faceIndex: 0) == nil)
    }

    // MARK: - A second class, found by probing rather than by the gate

    /// Three sites where the kernel, not the bridge, does the dereferencing.
    ///
    /// They touch no hazardous `TopoDS_Shape` member themselves, so the gate's third walk cannot
    /// see them and does not claim to: they hand the shape to `PrsDim_RadiusDimension`,
    /// `PrsDim_DiameterDimension` and `ShapeFix_Shape`, whose constructors dereference it inside
    /// the kernel. That is the shape-side equivalent of #556's "the OCCT entry point dereferences
    /// it for you", and the general sweep of which entry points do is a separate question. All
    /// three were measured crashing on a nullified shape.
    ///
    /// The eight further public operations sampled alongside them all already coped
    /// (`fused`, `subtracting`, `faces()`, `checkResult`, `linearProperties()`, `translated`,
    /// `mesh`, STEP export), so the residual is a sampled result, not a swept one.
    @Test("Kernel-side dereferences of a nullified shape are refused too")
    func kernelSideDereferencesAreRefused() throws {
        let nullShape = try makeNullShape()
        #expect(RadiusDimension(shape: nullShape) == nil)
        #expect(DiameterDimension(shape: nullShape) == nil)
        #expect(nullShape.healed() == nil)
    }

    // MARK: - Reporting the absence rather than conflating it with a negative

    /// The absence was already representable, under a name that does not read like it.
    ///
    /// `isEmptyShape` is `OCCTShapeIsEmpty`, which is literally `shape->shape.IsNull()`, so
    /// nothing new was added for it here, per `okf/policies/search-before-building.md`.
    @Test("isEmptyShape separates a nullified shape from a real one and from an emptied one")
    func isEmptyShapeSeparatesANullifiedShapeFromARealOne() throws {
        let box = try makeBox()
        #expect(box.isEmptyShape == false)
        #expect(try #require(box.nullified).isEmptyShape == true)
        // emptied() is TopoDS_Shape::EmptyCopied(), which keeps the type and drops the
        // sub-shapes, so it is NOT null and the property named for emptiness reads false on it.
        let emptied = try #require(box.emptied)
        #expect(emptied.isEmptyShape == false)
        #expect(emptied.shapeType == .solid)
    }

    // MARK: - Why the five Edge/Face-facing sites are a contract pin, not a proof

    @Test("Edge and Face refuse a nullified shape, so no null Edge or Face exists to pass on")
    func edgeAndFaceRefuseANullifiedShape() throws {
        let nullShape = try makeNullShape()
        #expect(Edge(nullShape) == nil)
        #expect(Face(nullShape) == nil)
    }

    // MARK: - The guards did not swallow a real answer

    @Test("Every guarded query still answers for a real box and a real face")
    func everyGuardedQueryStillAnswersForARealShape() throws {
        let box = try makeBox()
        #expect(box.shapeType == .solid)
        #expect(box.isValidSolid == true)
        #expect(box.isSolid == true)
        #expect(box.isCompound == false)
        #expect(box.isShell == false)
        #expect(box.isFace == false)
        #expect(box.isEdge == false)
        #expect(box.shapeTypeString == "solid")
        #expect(box.typeName == "SOLID")

        let faces = box.subShapes(ofType: .face)
        try #require(faces.count == 6)
        let hitCounts = faces.map {
            $0.intersectLine(
                origin: SIMD3(0, 0, -50), direction: SIMD3(0, 0, 1), paramRange: -1000...1000
            ).count
        }
        // A z-axis line meets the box's two z-normal faces and misses the other four, so the
        // guarded call still returns a real, non-empty measurement for at least one face.
        #expect(hitCounts.reduce(0, +) == 2)

        let edges = box.subShapes(ofType: .edge)
        try #require(!edges.isEmpty)
        let edge = try #require(Edge(edges[0]))
        let face = try #require(Face(faces[0]))
        #expect(edge.hasCurve3D == true)
        #expect(edge.isClosed3D == false)
        #expect(edge.isSeam(on: face) == false)
    }
}
