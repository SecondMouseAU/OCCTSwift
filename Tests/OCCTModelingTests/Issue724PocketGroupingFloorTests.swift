import Foundation
import Testing

@testable import OCCTSwift

// #724: `detectPocketsAAG()` reported 2 pockets for a single blind cylindrical pocket. Ground
// truth from OCCT's own classifier, `ChFi3d::DefineConnectType`: 13 convex, 1 concave (floor to
// wall), 1 tangential (the cylinder's own seam). One concave edge joining a wall to a floor is one
// pocket.
//
// The defect is in GROUPING, not classification (#723 is the separate, in-flight fix for
// `OCCTEdgeGetConvexity` itself, replacing its formula with `ChFi3d::DefineConnectType`). Measured
// directly: `detectPockets()`'s current formula still (mis)classifies a curved wall's rim, where
// the wall meets the exterior surface it opens through, as concave, even on this branch, after
// #703's face1/face2 order fix. #703 fixed a planar/planar order-dependence; it did not make
// `OCCTEdgeGetConvexity` correct for a planar/cylindrical pair, which is exactly what a bored
// pocket's rim is. That residual misclassification feeds `detectPockets()`'s
// `isUpward && isHorizontal && isPlanar` floor test: the box's own exterior top face satisfies it
// too, and once its rim edge to the cylindrical wall is (wrongly) concave, it looks exactly like a
// second, shallower floor for the same wall.
//
// The fix does not touch classification at all. It adds one more requirement to a candidate wall,
// independent of why that wall's edge classified concave: the floor must sit at the wall's own
// lowest Z. A pocket floor is upward-facing, so it is always the LOW end of the walls that rise
// from it; a wall's high end is where it opens, whether to the exterior, to a shallower pocket's
// floor, or to open air, never to a floor of its own. See `AAG.detectPockets()`'s doc comment in
// `FeatureRecognition.swift` for the full reasoning, including the one acknowledged limitation
// (a filleted floor/wall junction).
@Suite("detectPocketsAAG() does not double-count a pocket's floor (#724)")
struct Issue724PocketGroupingFloorTests {

    // MARK: - The headline

    /// The issue's own construction, byte for byte. A cylinder bored from the box's top face
    /// partway down (tool height 20 against a box that is only 10 above the tool's own base at
    /// z=0) leaves one real floor, at z=0, walled by the cylinder's lateral surface. The box's own
    /// top face, at z=10, is the pocket's OPENING, not a second floor.
    @Test("a single blind cylindrical pocket reports exactly one pocket")
    func blindCylindricalPocketReportsOne() throws {
        let box = try #require(
            Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(
            Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 4, height: 20))
        let cut = try #require(box.subtracting(tool))

        let pockets = cut.detectPocketsAAG()
        #expect(pockets.count == 1)

        guard let pocket = pockets.first else { return }
        // The real floor is at z=0 (the bottom of the bore), not z=10 (the box's own top, where
        // the bore opens to the exterior). Asserting the level, not just the count, rules out the
        // fix accidentally keeping the WRONG one of the two candidates.
        #expect(abs(pocket.zLevel - 0.0) < 1e-6)
        // One wall: the cylinder's lateral face. The false floor at z=10 shared that exact same
        // wall face, which is what made this bug a duplicate-count rather than a wrong-index bug.
        #expect(pocket.wallFaceIndices.count == 1)
    }

    // MARK: - The mechanism generalizes across depth

    /// Same shape, three tool heights that all leave the same z=0 floor but change how far the
    /// tool's own top extends past the box's top face. If the fix were keyed to the specific
    /// numbers in the issue rather than the general "floor is the wall's low Z" rule, at least one
    /// of these would still double-count.
    @Test(
        "holds across tool heights that all clear the box's top face",
        arguments: [15.0, 20.0, 40.0])
    func holdsAcrossToolHeight(height: Double) throws {
        let box = try #require(
            Shape.box(origin: SIMD3(-10, -10, -10), width: 20, height: 20, depth: 20))
        let tool = try #require(
            Shape.cylinder(at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 4, height: height)
        )
        let cut = try #require(box.subtracting(tool))

        #expect(cut.detectPocketsAAG().count == 1, "height=\(height)")
    }

    // MARK: - Non-regression: a genuine multi-wall pocket keeps every wall

    /// The doc-comment fixture (`Shape.detectPocketsAAG()`'s own example): a square pocket whose
    /// four walls all bottom out at the same floor. #724's fix filters a wall OUT of a floor's
    /// `wallFaceIndices` when the wall's own low Z does not match that floor; it must not filter
    /// a wall out just for being one of several that DO match. All four walls of a real, single-
    /// level pocket share the same floor Z, so all four must survive.
    @Test("a genuine four-walled pocket keeps all four walls")
    func genuineFourWalledPocketKeepsAllWalls() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let pocketTool = try #require(
            Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15))
        let result = try #require(box.subtracting(pocketTool))

        let pockets = result.detectPocketsAAG()
        #expect(pockets.count == 1)
        #expect(pockets.first?.wallFaceIndices.count == 4)
    }

    /// The suite's own pinned square-pocket fixture (`Issue703EdgeConvexityOrderTests`), at
    /// several depths, stays at exactly one pocket. This fixture already has 8 concave edges
    /// (4 floor/wall + 4 wall/wall corners) with none of the rim-misclassification #724's own
    /// headline exercises, confirming the fix changes nothing for a pocket that was already
    /// correctly grouped.
    @Test(
        "the pinned square-pocket fixture is unaffected, at several depths",
        arguments: [2.0, 10.0, 25.0])
    func pinnedSquarePocketFixtureUnaffected(depth: Double) throws {
        let box = try #require(Shape.box(width: 30, height: 30, depth: 30))
        let pocket = try #require(
            Shape.box(
                origin: SIMD3(-5, -5, 15 - depth), width: 10, height: 10, depth: depth + 1))
        let pocketed = try #require(box.subtracting(pocket))

        #expect(pocketed.detectPocketsAAG().count == 1, "depth=\(depth)")
    }

    /// A plain box has no concave edges at all (#703), so there is no floor candidate in the first
    /// place; #724's extra wall-bottom check must not manufacture one.
    @Test("a plain box still reports zero pockets")
    func plainBoxStillReportsZero() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.detectPocketsAAG().count == 0)
    }
}
