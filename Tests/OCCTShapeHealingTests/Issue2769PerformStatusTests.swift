import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #2769: the `ShapeUpgrade_ShapeDivide` family's failure signal is `Perform()` returning false
/// **and** `Status(ShapeExtend_FAIL)`, not either half on its own.
///
/// OCCT's own production caller settles it. `ShapeProcess_OperLibrary.cxx`, the shape-processing
/// library STEP and IGES import healing runs through, reads the pair at all five of its
/// family call sites:
///
/// ```
/// if (!tool.Perform() && tool.Status(ShapeExtend_FAIL))
///   return false;                    // the failure path
/// ctx->SetResult(tool.Result());     // success, including when Perform() returned false
/// ```
///
/// So `false` alone means "nothing was done", with `Result()` holding the valid input shape. Until
/// #2769 the wrappers behind the entry points below gated on `Perform()` alone, so an input with
/// nothing to do came back as `nil`. Each test here pairs that no-op input with a control input the
/// same operation can genuinely act on, so a bridge that started handing back its input
/// unconditionally would fail the test rather than satisfying it.
///
/// Measured in `Scripts/repro/2765-convert-to-bezier-perform/` (`siblings.mm` and its transcript in
/// `README.md`), which records `Perform()`, `Status(ShapeExtend_FAIL)` and `Result().IsNull()` side
/// by side for all eleven wrappers.
@Suite("Issue #2769: nothing to do is not a failure (healing entry points)")
struct Issue2769PerformStatusTests {

    /// A cubic BSpline face with a multiplicity-3 interior knot in U and V, so it is genuinely C0
    /// rather than C1 at that knot. Same recipe as
    /// `Issue438DivideContinuityUnificationTests.kinkedSurfaceFace()`, kept local because it is the
    /// only fixture `divided(at:)` visibly splits: measured, a box, a cylinder, a sphere, a cone
    /// and a torus all come back unchanged at every continuity level.
    private func kinkedSurfaceFace() -> Shape? {
        let degree = 3
        let interiorKnots = 4
        let bumpAt = 2
        let bumpMult = 3
        var knots: [Double] = [0]
        var mults: [Int32] = [Int32(degree + 1)]
        for i in 1...interiorKnots {
            knots.append(Double(i))
            mults.append(Int32(i == bumpAt ? bumpMult : 1))
        }
        knots.append(Double(interiorKnots + 1))
        mults.append(Int32(degree + 1))
        let poleCount = Int(mults.reduce(0, +)) - degree - 1

        guard
            let surface = Surface.bspline(
                poles: (0..<poleCount).map { u in
                    (0..<poleCount).map { v in
                        SIMD3<Double>(Double(u), Double(v), Double((u + v) % 3) * 0.5)
                    }
                },
                knotsU: knots, multiplicitiesU: mults,
                knotsV: knots, multiplicitiesV: mults,
                degreeU: degree, degreeV: degree)
        else { return nil }
        let bounds = surface.domain
        return Shape.face(
            from: surface, uRange: bounds.uMin...bounds.uMax, vRange: bounds.vMin...bounds.vMax)
    }

    // MARK: - Group A: a no-op input used to come back as nil

    @Test("divided(at:) on an all-planar box returns the box, and still splits a kinked surface")
    func dividedReturnsTheInputWhenNothingDropsBelowTheCriterion() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        // Every face of a box is planar, so nothing is below C0. Before #2769 this was nil.
        let unchanged = try #require(box.divided(at: .c0))
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: box), "Result() is the input shape, not a rebuild of it")
        #expect(abs(try #require(unchanged.volume) - 6000.0) < 1e-6)

        // Control: the same entry point on a surface it can genuinely split. A bridge that handed
        // back its input unconditionally would pass the block above and fail here.
        let kinked = try #require(kinkedSurfaceFace())
        #expect(kinked.subShapes(ofType: .face).count == 1)
        let split = try #require(kinked.divided(at: .c1, tolerance: 1e-4))
        #expect(split.subShapes(ofType: .face).count == 4, "the mult-3 knot splits U and V")
        #expect(!split.isSame(as: kinked))
    }

    @Test("dividedByNumber on a face-less shape returns it, and still splits a box")
    func dividedByNumberReturnsTheInputWhenThereIsNoFaceToSplit() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))

        // `dividedByNumber(_:)` refuses parts <= 1 in Swift, so the reachable no-op is a shape with
        // no face at all: the splitter runs and finds nothing to do. Before #2769 this was nil.
        let line = try #require(box.edges().first(where: { $0.curveType == .line }))
        let edgeShape = try #require(Shape.fromEdge(line))
        #expect(edgeShape.subShapes(ofType: .face).isEmpty)

        let unchanged = try #require(edgeShape.dividedByNumber(2))
        #expect(unchanged.subShapes(ofType: .edge).count == 1)
        #expect(unchanged.isSame(as: edgeShape))

        // Control.
        let split = try #require(box.dividedByNumber(2))
        #expect(split.subShapes(ofType: .face).count == 8)
        #expect(!split.isSame(as: box))
    }

    @Test("dividedClosedFaces on a box returns the box, and still splits a cylinder")
    func dividedClosedFacesReturnsTheInputWhenNoFaceIsClosed() throws {
        let cube = try #require(Shape.box(width: 10, height: 10, depth: 10))

        // No face of a box wraps onto itself. Before #2769 this was nil, and
        // docs/reference/Shape-Measurement.md documented that nil.
        let unchanged = try #require(cube.dividedClosedFaces(splitPoints: 2))
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: cube))
        #expect(abs(try #require(unchanged.volume) - 1000.0) < 1e-6)

        // Control: a cylinder's lateral face is closed.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let split = try #require(cyl.dividedClosedFaces(splitPoints: 2))
        #expect(split.subShapes(ofType: .face).count == 5, "3 faces, the wall becomes 3")
        #expect(!split.isSame(as: cyl))
    }

    @Test("OCCTShapeUpgradeSplitSurfaceAngle, which has no Swift caller, follows the same rule")
    func bridgeOnlySplitSurfaceAngleReturnsTheInputWhenNothingSpansTheAngle() throws {
        // This bridge function is `OCCTShapeSplitByAngle` a second time: both build
        // `ShapeUpgrade_ShapeDivideAngle(maxAngleDegrees * M_PI / 180.0, shape)` with no further
        // configuration. It has no Swift caller, no reference page and, until now, no test, so it
        // is reached here through `import OCCTBridge`. Whether it keeps its place is #2771's
        // question; while it exists it obeys the same rule as its twin.
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let unchangedRef = try #require(OCCTShapeUpgradeSplitSurfaceAngle(box.handle, 90))
        let unchanged = Shape(handle: unchangedRef)
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: box))

        // Control.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let splitRef = try #require(OCCTShapeUpgradeSplitSurfaceAngle(cyl.handle, 45))
        let split = Shape(handle: splitRef)
        #expect(split.subShapes(ofType: .face).count == 10)
        #expect(!split.isSame(as: cyl))
    }

    // MARK: - Group B: the return value used to be ignored outright

    // These two already returned the input shape on a no-op, which is correct, and #2769 changed
    // only what they do on a `Status(ShapeExtend_FAIL)`. The tests pin the half that is reachable:
    // restoring a bare `if (!converter.Perform()) return nullptr;`, which is what PR #2743's review
    // asked for, has to fail. The failure half has no test, and
    // Scripts/repro/2765-convert-to-bezier-perform/README.md says what was tried and why.

    @Test("convertCurves3dToBezier with every mode off returns the input, not nil")
    func convertCurves3dToBezierWithNoModeEnabledReturnsTheInput() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let unchanged = try #require(
            box.convertCurves3dToBezier(lineMode: false, circleMode: false, conicMode: false))
        #expect(unchanged.subShapes(ofType: .edge).count == 12)
        #expect(unchanged.isSame(as: box))

        // Control: a box's edges are lines, so lineMode alone has work to do.
        let converted = try #require(box.convertCurves3dToBezier(lineMode: true))
        #expect(!converted.isSame(as: box))
        #expect(converted.edges().allSatisfy { $0.curveType == .bezierCurve })
    }

    @Test("convertSurfacesToBezier with every mode off returns the input, not nil")
    func convertSurfacesToBezierWithNoModeEnabledReturnsTheInput() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let unchanged = try #require(
            box.convertSurfacesToBezier(
                planeMode: false, revolutionMode: false, extrusionMode: false, bsplineMode: false))
        #expect(unchanged.subShapes(ofType: .face).count == 6)
        #expect(unchanged.isSame(as: box))

        // Control: a box's faces are planes.
        let converted = try #require(box.convertSurfacesToBezier(planeMode: true))
        #expect(!converted.isSame(as: box))
        #expect(converted.subShapes(ofType: .face).count == 6)
    }
}
