import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepBndLib")
struct BRepBndLibTests {
    @Test func shapeBoundingBox() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let bb = b.boundingBox
            #expect(bb != nil)
            if let bb = bb {
                #expect(bb.max.x - bb.min.x > 9.0)
                #expect(bb.max.y - bb.min.y > 19.0)
                #expect(bb.max.z - bb.min.z > 29.0)
            }
        }
    }

    @Test func shapeBoundingBoxOptimal() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let bb = b.boundingBoxOptimal()
            #expect(bb != nil)
            if let bb = bb {
                #expect(bb.max.x - bb.min.x > 9.0)
                #expect(bb.max.y - bb.min.y > 19.0)
                #expect(bb.max.z - bb.min.z > 29.0)
            }
        }
    }

    @Test func shapeBoundingBoxOptimalWithTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let bb = b.boundingBoxOptimal(useShapeTolerance: true)
            #expect(bb != nil)
        }
    }

    @Test func orientedBoundingBoxDetailed() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let obb = b.orientedBoundingBoxDetailed()
            #expect(obb != nil)
            if let obb = obb {
                #expect(obb.xHalfSize > 0)
                #expect(obb.yHalfSize > 0)
                #expect(obb.zHalfSize > 0)
            }
        }
    }

    @Test func orientedBoundingBoxDetailedOptimal() {
        let sphere = Shape.sphere(radius: 5)
        if let s = sphere {
            let obb = s.orientedBoundingBoxDetailed(optimal: true)
            #expect(obb != nil)
        }
    }

    // #847: orientedBoundingBoxDetailed shares its Bnd_OBB computation with orientedBoundingBox,
    // this was previously unenforced by any test, so the two could have silently diverged.
    @Test func orientedBoundingBoxDetailedMatchesPacked() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
            .rotated(axis: SIMD3(0, 0, 1), angle: .pi / 6)!
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

    @Test func boundingBoxSphere() {
        let sphere = Shape.sphere(radius: 10)
        if let s = sphere {
            let bb = s.boundingBox
            #expect(bb != nil)
            if let bb = bb {
                // Sphere of radius 10 should have bounds approximately [-10, 10] in each axis
                #expect(bb.min.x < -9.0)
                #expect(bb.max.x > 9.0)
            }
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
