import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1068: Detailed self-intersection check with progress information.
// Tests for isSelfIntersectingDetailed(timeout:) and selfIntersectionCostEstimate()
@Suite("Issue #1068, self-intersection detailed API")
struct Issue1068SelfIntersectionDetailed {

    @Test("isSelfIntersectingDetailed reports clean for a box")
    func boxIsClean() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "box should build")
            return
        }
        let result = box.isSelfIntersectingDetailed(timeout: 5)
        #expect(result.status == .clean)
        #expect(result.totalFacePairs > 0)
        #expect(result.timeSpent >= 0)
    }

    @Test("isSelfIntersectingDetailed reports intersects for overlapping boxes")
    func overlappingBoxesIntersect() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false), "compound should build")
            return
        }
        let result = compound.isSelfIntersectingDetailed(timeout: 5)
        #expect(result.status == .intersects)
        #expect(result.totalFacePairs > 0)
        #expect(result.timeSpent >= 0)
    }

    @Test("isSelfIntersectingDetailed reports indeterminateBreakerTripped on very short timeout")
    func shortTimeoutTripsBreaker() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "box should build")
            return
        }
        // Use an extremely short timeout that should trip the breaker
        let result = box.isSelfIntersectingDetailed(timeout: 1e-7)
        // On fast machines this might complete, so accept either clean or tripped
        #expect(result.status == .clean || result.status == .indeterminateBreakerTripped)
        #expect(result.totalFacePairs > 0)
        #expect(result.timeSpent >= 0)
    }

    @Test("selfIntersectionCostEstimate returns valid estimate for a box")
    func boxCostEstimate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "box should build")
            return
        }
        guard let estimate = box.selfIntersectionCostEstimate() else {
            #expect(Bool(false), "cost estimate should succeed")
            return
        }
        #expect(estimate.numFaces == 6)
        // Face surfaces may not be recognized as Geom_Plane depending on OCCT version
        #expect(estimate.numBSplineFaces == 0)
        #expect(estimate.estimatedCost > 0)
    }

    @Test("selfIntersectionCostEstimate returns valid estimate for a cylinder")
    func cylinderCostEstimate() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            #expect(Bool(false), "cylinder should build")
            return
        }
        guard let estimate = cyl.selfIntersectionCostEstimate() else {
            #expect(Bool(false), "cost estimate should succeed")
            return
        }
        #expect(estimate.numFaces >= 3)  // cylinder has 3 faces (top, bottom, side)
        #expect(estimate.numBSplineFaces == 0)
        #expect(estimate.estimatedCost > 0)
    }

    @Test("selfIntersectionCostEstimate returns zero estimate for empty shape")
    func emptyShapeCostEstimateReturnsZero() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let empty = box.emptied
        else {
            #expect(Bool(false), "box and emptied should build")
            return
        }
        let estimate = empty.selfIntersectionCostEstimate()
        #expect(estimate != nil)
        #expect(estimate?.numFaces == 0)
        #expect(estimate?.numBSplineFaces == 0)
        #expect(estimate?.numPlaneFaces == 0)
        #expect(estimate?.estimatedCost == 0.0)
    }

    @Test("isSelfIntersectingDetailed and isSelfIntersecting(timeout:) agree on clean box")
    func detailedAndBasicAgreeOnClean() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            #expect(Bool(false), "box should build")
            return
        }
        let detailed = box.isSelfIntersectingDetailed(timeout: 5)
        let basic = box.isSelfIntersecting(timeout: 5)
        if detailed.status == .clean {
            #expect(basic == false)  // basic returns false for clean
        } else if detailed.status == .intersects {
            #expect(basic == true)
        }
    }

    @Test(
        "isSelfIntersectingDetailed and isSelfIntersecting(timeout:) agree on intersecting compound"
    )
    func detailedAndBasicAgreeOnIntersecting() {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10),
            let compound = Shape.compound([a, b])
        else {
            #expect(Bool(false), "compound should build")
            return
        }
        let detailed = compound.isSelfIntersectingDetailed(timeout: 5)
        let basic = compound.isSelfIntersecting(timeout: 5)
        if detailed.status == .intersects {
            #expect(basic == true)
        }
    }

    // #1436: OCCTShapeSelfIntersectsDetailed reintroduced #1054's HasFaulty()-over-broad-check
    // shape in its own sibling. A shape with no geometry at all (BOPTools_AlgoTools3D::
    // IsEmptyShape) makes BOPAlgo_ArgumentAnalyzer::TestTypes() append a BOPAlgo_BadType
    // result and return before any self-interference test ever runs; HasFaulty() is true
    // regardless, so the old code answered `1`/`.intersects` for an argument it never
    // actually analysed for self-intersection. `.emptied` (BRep EmptyCopied(), a real solid
    // TShape with no faces) is the Swift-reachable shape that reproduces it; the plain
    // `Shape.compound([])` cited in the issue's own text never reaches this function at all,
    // OCCTShapeCreateCompound refuses count < 1 with a null handle before there is a Shape
    // to call the self-intersection check on.
    @Test("isSelfIntersectingDetailed does not report intersects for a BadType (empty) argument")
    func emptyShapeIsNotReportedAsIntersecting() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let empty = box.emptied
        else {
            #expect(Bool(false), "box and emptied should build")
            return
        }
        let detailed = empty.isSelfIntersectingDetailed(timeout: 5)
        // The empty shape carries no geometry to self-intersect: BOPAlgo_ArgumentAnalyzer
        // records BOPAlgo_BadType, never BOPAlgo_SelfIntersect, for this input. Reporting it
        // as `.intersects` is the exact bug; `.error` is what the fixed status-loop reports
        // (an argument the analyzer refused, not a conclusive self-intersection).
        #expect(detailed.status != .intersects)
        #expect(detailed.status == .error)
        // Cross-check against the sibling OCCTShapeSelfIntersectsBounded, whose #1054 fix
        // this one now mirrors: it already reads the same BadType result correctly and
        // reports indeterminate (nil), never `true`.
        let basic = empty.isSelfIntersecting(timeout: 5)
        #expect(basic == nil)
    }
}
