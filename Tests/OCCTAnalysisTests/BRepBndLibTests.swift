import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `Precision::Confusion()`, which is the tolerance `BRep_Builder` floors every vertex of a
/// primitive at, and therefore the amount `BRepBndLib::Add` and `BRepBndLib::AddOBB` enlarge the
/// box of a `BRepPrimAPI_*` solid by on every side.
///
/// It is written out rather than absorbed into a loose tolerance so that the tests below
/// distinguish the three entry points from each other: `Add` always adds it, `AddOptimal` adds it
/// only when asked, and a test comparing against the nominal extent at 1e-6 could not see which
/// of the three it had called. Values probed in `Scripts/repro/766-brepbndlib/`.
private let shapeTolerance = 1e-7

/// `Shape.box(width:height:depth:)` centres on the origin, so a 10 x 20 x 30 box spans
/// x in [-5, 5], y in [-10, 10] and z in [-15, 15] before any tolerance.
private let boxHalfExtent = SIMD3<Double>(5, 10, 15)

/// All six coordinates of an axis-aligned box, to 1e-12, which is five orders tighter than
/// ``shapeTolerance`` and so still separates "tolerance added" from "tolerance not added".
private func expectBox(
    _ b: (min: SIMD3<Double>, max: SIMD3<Double>), min: SIMD3<Double>, max: SIMD3<Double>,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        simd_distance(b.min, min) < 1e-12, "min \(b.min), expected \(min)",
        sourceLocation: sourceLocation)
    #expect(
        simd_distance(b.max, max) < 1e-12, "max \(b.max), expected \(max)",
        sourceLocation: sourceLocation)
}

/// The three axes of a ``Shape/DetailedOBB`` are an orthonormal frame, whatever orientation
/// `Bnd_OBB` chose. Pinning the half-sizes without this would not notice a frame that had
/// collapsed or lost normalisation, which is what makes the half-sizes mean anything.
private func expectOrthonormalFrame(
    _ obb: Shape.DetailedOBB, sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(abs(simd_length(obb.xDirection) - 1) < 1e-12, sourceLocation: sourceLocation)
    #expect(abs(simd_length(obb.yDirection) - 1) < 1e-12, sourceLocation: sourceLocation)
    #expect(abs(simd_length(obb.zDirection) - 1) < 1e-12, sourceLocation: sourceLocation)
    #expect(abs(simd_dot(obb.xDirection, obb.yDirection)) < 1e-12, sourceLocation: sourceLocation)
    #expect(abs(simd_dot(obb.yDirection, obb.zDirection)) < 1e-12, sourceLocation: sourceLocation)
    #expect(abs(simd_dot(obb.xDirection, obb.zDirection)) < 1e-12, sourceLocation: sourceLocation)
}

@Suite("BRepBndLib")
struct BRepBndLibTests {
    /// `BRepBndLib::Add` walks the shape's vertices, edges and faces and enlarges the box by each
    /// one's tolerance, so a primitive box comes back one ``shapeTolerance`` oversize on every
    /// side. The old form asserted each span exceeded a threshold the nominal box clears by a
    /// whole unit, so it could not see the box mis-centred, nor the tolerance dropped (#1869).
    @Test func shapeBoundingBox() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let bb = try #require(b.boundingBox)
        let half = boxHalfExtent + SIMD3(repeating: shapeTolerance)
        expectBox(bb, min: -half, max: half)
    }

    /// `BRepBndLib::AddOptimal` with `useShapeTolerance` off measures the geometry alone, so the
    /// same box comes back at exactly its nominal extent, with no tolerance added (#1870).
    @Test func shapeBoundingBoxOptimal() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let bb = try #require(b.boundingBoxOptimal())
        expectBox(bb, min: -boxHalfExtent, max: boxHalfExtent)
    }

    /// #1871: this asserted only `bb != nil`, so a bridge that dropped `useShapeTolerance`
    /// entirely and measured the exact box instead passed. The flag's whole effect is one
    /// ``shapeTolerance`` on each side, so the two calls are made here side by side and the
    /// difference between them is what the test pins.
    @Test func shapeBoundingBoxOptimalWithTolerance() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let withTolerance = try #require(b.boundingBoxOptimal(useShapeTolerance: true))
        let exact = try #require(b.boundingBoxOptimal())
        let half = boxHalfExtent + SIMD3(repeating: shapeTolerance)
        expectBox(withTolerance, min: -half, max: half)
        expectBox(exact, min: -boxHalfExtent, max: boxHalfExtent)
    }

    /// #1872: this asserted the three half-sizes were positive, which the box of any non-empty
    /// shape satisfies. For an axis-aligned box `BRepBndLib::AddOBB` returns the axis-aligned
    /// frame, so the half-sizes are the nominal half-extents plus one ``shapeTolerance`` each,
    /// in order, about a centre at the origin.
    @Test func orientedBoundingBoxDetailed() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let obb = try #require(b.orientedBoundingBoxDetailed())
        let half = boxHalfExtent + SIMD3(repeating: shapeTolerance)
        #expect(abs(obb.xHalfSize - half.x) < 1e-12)
        #expect(abs(obb.yHalfSize - half.y) < 1e-12)
        #expect(abs(obb.zHalfSize - half.z) < 1e-12)
        #expect(simd_length(obb.center) < 1e-12)
        expectOrthonormalFrame(obb)
    }

    /// #1873: this asserted only `obb != nil`. A radius-5 sphere has no preferred orientation, so
    /// whatever frame `AddOBB` picks the three half-sizes are all the radius plus one
    /// ``shapeTolerance``, about a centre on the origin.
    @Test func orientedBoundingBoxDetailedOptimal() throws {
        let s = try #require(Shape.sphere(radius: 5))
        let obb = try #require(s.orientedBoundingBoxDetailed(optimal: true))
        let half = 5 + shapeTolerance
        #expect(abs(obb.xHalfSize - half) < 1e-12)
        #expect(abs(obb.yHalfSize - half) < 1e-12)
        #expect(abs(obb.zHalfSize - half) < 1e-12)
        #expect(simd_length(obb.center) < 1e-12)
        expectOrthonormalFrame(obb)
    }

    // #847: orientedBoundingBoxDetailed shares its Bnd_OBB computation with orientedBoundingBox,
    // this was previously unenforced by any test, so the two could have silently diverged.
    /// Agreeing on a wrong box is also agreement, so the box itself is pinned alongside: an
    /// oriented box turns with the shape, so a box rotated 30 degrees about z keeps the
    /// half-sizes it had before the turn.
    @Test func orientedBoundingBoxDetailedMatchesPacked() throws {
        let box = try #require(
            Shape.box(width: 10, height: 20, depth: 30)?
                .rotated(axis: SIMD3(0, 0, 1), angle: .pi / 6))
        let packed = try #require(box.orientedBoundingBox())
        let detailed = try #require(box.orientedBoundingBoxDetailed())
        #expect(abs(packed.center.x - detailed.center.x) < 1e-9)
        #expect(abs(packed.center.y - detailed.center.y) < 1e-9)
        #expect(abs(packed.center.z - detailed.center.z) < 1e-9)
        #expect(abs(packed.halfSizes.x - detailed.xHalfSize) < 1e-9)
        #expect(abs(packed.halfSizes.y - detailed.yHalfSize) < 1e-9)
        #expect(abs(packed.halfSizes.z - detailed.zHalfSize) < 1e-9)

        let half = boxHalfExtent + SIMD3(repeating: shapeTolerance)
        #expect(simd_distance(packed.halfSizes, half) < 1e-9)
        #expect(simd_length(packed.center) < 1e-9)
    }

    /// #1875: `bb.min.x < -9` and `bb.max.x > 9` hold of any box a radius-10 sphere could
    /// plausibly produce and of a good many it could not. `BRepBndLib::Add` on the sphere gives
    /// the cube of the radius plus one ``shapeTolerance`` on every side, which is the same sphere
    /// `BndLibTests.faceBounds` measures through `BndLib_AddSurface` at tolerance 0.
    @Test func boundingBoxSphere() throws {
        let s = try #require(Shape.sphere(radius: 10))
        let bb = try #require(s.boundingBox)
        let half = SIMD3<Double>(repeating: 10 + shapeTolerance)
        expectBox(bb, min: -half, max: half)
    }

    // #834 added this with the two sides disagreeing: `boundingBox` answered nil for a void
    // shape and `bounds` fabricated (0,0,0)-(0,0,0), indistinguishable from a genuine zero-size
    // shape at the origin. #943 converged them, so all four accessors answer nil here and the
    // test name says so. The zero-size half of the same contract is
    // pointVertexAtOriginBoundingBoxIsNotNil below, and Issue943BoundsVoid covers both.
    @Test func voidShapeReportsNoBoxFromAnyAccessor() throws {
        // A far-disjoint intersection is the reliable way to get a genuinely void Shape:
        // Shape.compound([]) refuses to construct (OCCTShapeCreateCompound requires count >= 1).
        let voidShape = try #require(
            makeVoidShape(), "disjoint intersection should still construct a (void) shape")
        #expect(voidShape.boundingBox == nil)
        #expect(voidShape.bounds == nil)
        #expect(voidShape.size == nil)
        #expect(voidShape.center == nil)
    }

    // #900: a point-vertex shape at the world origin legitimately measures to all-zero
    // coordinates, which used to be indistinguishable from bridge/void failure (both call sites
    // inferred failure from "all six coordinates are exactly zero"). `boundingBoxOptimal` has a
    // live repro, `BRepBndLib::AddOptimal` on a vertex at .zero measures exactly
    // (0,0,0)-(0,0,0), so this used to return `nil` instead of the correct all-zero box.
    // `boundingBox` (`BRepBndLib::Add`) is not concretely reachable through this same fixture,
    // `BRep_Builder::MakeVertex` floors the vertex tolerance at `Precision::Confusion()`, so
    // `Add`'s enlargement never lands on exact zero, but it shares the same fixed bridge
    // contract, so this test still pins the non-regression on the ordinary path.
    @Test func pointVertexAtOriginBoundingBoxIsNotNil() throws {
        let origin = try #require(makePointVertexAtOrigin())

        let optimal = try #require(origin.boundingBoxOptimal())
        #expect(optimal.min == SIMD3<Double>.zero)
        #expect(optimal.max == SIMD3<Double>.zero)

        // Not a live repro (see comment above) -- this asserts non-regression, not a fixed bug.
        // That floored vertex tolerance is exactly what makes this box non-zero, so it is pinned
        // rather than absorbed: a `< 1e-6` comparison passes on both 0 and 1e-7, and so cannot
        // tell `Add` from `AddOptimal`.
        let ordinary = try #require(origin.boundingBox)
        let half = SIMD3<Double>(repeating: shapeTolerance)
        expectBox(ordinary, min: -half, max: half)
    }
}
