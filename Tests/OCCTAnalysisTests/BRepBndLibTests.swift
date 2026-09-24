import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepBndLib")
struct BRepBndLibTests {
    // Shape.box(width:height:depth:) is centred on the origin, so a 10 x 20 x 30 box spans
    // x in [-5, 5], y in [-10, 10], z in [-15, 15]. Fixtures are required rather than
    // `if let`-wrapped (#766): a nil fixture used to skip every assertion and pass.
    @Test func shapeBoundingBox() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let bb = b.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.max.x - bb.min.x > 9.0)
            #expect(bb.max.y - bb.min.y > 19.0)
            #expect(bb.max.z - bb.min.z > 29.0)
        }
    }

    @Test func shapeBoundingBoxOptimal() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let bb = b.boundingBoxOptimal()
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.max.x - bb.min.x > 9.0)
            #expect(bb.max.y - bb.min.y > 19.0)
            #expect(bb.max.z - bb.min.z > 29.0)
        }
    }

    // #766: this asserted only `bb != nil`, so a bridge that dropped `useShapeTolerance` and
    // measured the exact box instead passed. Probed in Scripts/repro/766-brepbndlib: with the
    // flag, `BRepBndLib::AddOptimal` widens every side by the box's 1e-7 vertex tolerance, so
    // x spans [-5.0000001, 5.0000001]; without it the box is exactly [-5, 5].
    @Test func shapeBoundingBoxOptimalWithTolerance() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let withTolerance = try #require(b.boundingBoxOptimal(useShapeTolerance: true))
        let exact = try #require(b.boundingBoxOptimal())
        #expect(abs(withTolerance.min.x - (-5.0000001)) < 1e-12)
        #expect(abs(withTolerance.max.z - 15.0000001) < 1e-12)
        #expect(exact.min.x == -5)
        #expect(exact.max.z == 15)
    }

    @Test func orientedBoundingBoxDetailed() throws {
        let b = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let obb = b.orientedBoundingBoxDetailed()
        #expect(obb != nil)
        if let obb = obb {
            // Box 10x20x30 centred at origin: half-sizes 5, 10, 15 (probed with tolerance: 5.0000001, 10.0000001, 15.0000001)
            #expect(abs(obb.xHalfSize - 5.0) < 1e-6)
            #expect(abs(obb.yHalfSize - 10.0) < 1e-6)
            #expect(abs(obb.zHalfSize - 15.0) < 1e-6)
        }
    }

    // #766: this asserted only `obb != nil`. Probed: `BRepBndLib::AddOBB` with `optimal` set
    // measures a radius-5 sphere as three half-sizes of 5.0000001 (radius plus tolerance) about
    // a centre within 2e-16 of the origin.
    @Test func orientedBoundingBoxDetailedOptimal() throws {
        let s = try #require(Shape.sphere(radius: 5))
        let obb = try #require(s.orientedBoundingBoxDetailed(optimal: true))
        #expect(abs(obb.xHalfSize - 5.0000001) < 1e-9)
        #expect(abs(obb.yHalfSize - 5.0000001) < 1e-9)
        #expect(abs(obb.zHalfSize - 5.0000001) < 1e-9)
        #expect(simd_length(obb.center) < 1e-9)
    }

    // #847: orientedBoundingBoxDetailed shares its Bnd_OBB computation with orientedBoundingBox,
    // this was previously unenforced by any test, so the two could have silently diverged.
    @Test func orientedBoundingBoxDetailedMatchesPacked() throws {
        let box = try #require(
            Shape.box(width: 10, height: 20, depth: 30)?.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 6))
        let packed = box.orientedBoundingBox()
        let detailed = box.orientedBoundingBoxDetailed()
        #expect(packed != nil)
        #expect(detailed != nil)
        if let packed, let detailed {
            #expect(abs(packed.center.x - detailed.center.x) < 1e-9)
            #expect(abs(packed.center.y - detailed.center.y) < 1e-9)
            #expect(abs(packed.center.z - detailed.center.z) < 1e-9)
            #expect(abs(packed.halfSizes.x - detailed.xHalfSize) < 1e-9)
            #expect(abs(packed.halfSizes.y - detailed.yHalfSize) < 1e-9)
            #expect(abs(packed.halfSizes.z - detailed.zHalfSize) < 1e-9)
        }
    }

    @Test func boundingBoxSphere() throws {
        let s = try #require(Shape.sphere(radius: 10))
        let bb = s.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            // Sphere of radius 10 should have bounds approximately [-10, 10] in each axis
            // Probed with tolerance: -10.0000001, 10.0000001
            #expect(abs(bb.min.x - (-10.0)) < 1e-6)
            #expect(abs(bb.max.x - 10.0) < 1e-6)
        }
    }

    // #834 added this with the two sides disagreeing: `boundingBox` answered nil for a void
    // shape and `bounds` fabricated (0,0,0)-(0,0,0), indistinguishable from a genuine zero-size
    // shape at the origin. #943 converged them, so all four accessors answer nil here and the
    // test name says so. The zero-size half of the same contract is
    // pointVertexAtOriginBoundingBoxIsNotNil below, and Issue943BoundsVoid covers both.
    @Test func voidShapeReportsNoBoxFromAnyAccessor() throws {
        // A far-disjoint intersection is the reliable way to get a genuinely void Shape:
        // Shape.compound([]) refuses to construct (OCCTShapeCreateCompound requires count >= 1).
        let voidShape = try #require(makeVoidShape(), "disjoint intersection should still construct a (void) shape")
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

        let optimal = origin.boundingBoxOptimal()
        #expect(optimal != nil)
        if let optimal {
            #expect(optimal.min == SIMD3<Double>.zero)
            #expect(optimal.max == SIMD3<Double>.zero)
        }

        // Not a live repro (see comment above) -- this asserts non-regression, not a fixed bug.
        let ordinary = origin.boundingBox
        #expect(ordinary != nil)
        if let ordinary {
            #expect(
                abs(ordinary.min.x) < 1e-6 && abs(ordinary.min.y) < 1e-6
                    && abs(ordinary.min.z) < 1e-6)
            #expect(
                abs(ordinary.max.x) < 1e-6 && abs(ordinary.max.y) < 1e-6
                    && abs(ordinary.max.z) < 1e-6)
        }
    }
}
