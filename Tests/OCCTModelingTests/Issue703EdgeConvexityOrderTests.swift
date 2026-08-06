import Testing
import Foundation
@testable import OCCTSwift

// #703: `OCCTEdgeGetConvexity` reported a different convexity for the same physical edge
// depending on which face was passed as `face1` and which as `face2`. The formula it used, the
// sign of `(tangent × n1) · n2`, is a scalar triple product of the edge tangent and the two face
// normals; swapping which normal is `n1` and which is `n2` swaps two of its three vectors, which
// negates a triple product's sign. `AAG.buildGraph()`'s pairwise loop picks `face1`/`face2` by
// array position (`faces[i]`, `faces[j]`, `i < j`), not by any geometric convention, so the answer
// depended on face enumeration order rather than on geometry.
//
// Reproduced on the simplest possible input: a plain, uncut, convex 10mm box. A convex solid has
// no concave edges and therefore no pockets, so the correct `detectPocketsAAG().count` is 0. Two
// of the box's four side-wall-to-top-face dihedrals were classified concave purely because of
// index order, feeding a false pocket count of 1. The same false positive, once per box, explains
// the `1`/`2` pins `Issue642AAGNodeIdentityTests` and `Issue699AAGSolidScopedAdjacencyTests` used
// to carry on their own split-box fixtures -- see #664's census
// (`Scripts/repro/cluster-a-subshape-enumeration/README.md`, "Update following #699's fix") for
// where this was first measured, and this issue's own text for the confirmation.
//
// Fixed by replacing the order-dependent triple product with a formula built to be symmetric under
// the face1/face2 swap, not merely observed to be on the fixtures below: see
// `OCCTBridge_BRepGraph.mm`'s `OCCTEdgeGetConvexity` for the derivation and its own doc comment.
@Suite("OCCTEdgeGetConvexity is symmetric in face1/face2 (#703)")
struct Issue703EdgeConvexityOrderTests {

    /// The strongest test available (per the issue): no compound, no split, no shared face, and
    /// the correct answer is unarguably 0. A convex solid has zero concave edges by definition, so
    /// every dihedral of a plain box must classify convex and `detectPocketsAAG()` must report no
    /// pockets at all.
    @Test("a plain box has no concave edges and therefore no pockets")
    func plainBoxHasNoPockets() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the box")
            return
        }

        let aag = box.buildAAG()
        #expect(aag.edges.count == 12)
        #expect(aag.edges.allSatisfy { $0.convexity == .convex })
        #expect(box.detectPocketsAAG().count == 0)
    }

    /// Two plain boxes glued face to face (the exact construction `Issue642AAGNodeIdentityTests`
    /// and `Issue699AAGSolidScopedAdjacencyTests` pin) have no concave edge anywhere, in EITHER
    /// compound member order: neither piece is anything but a plain box, and the shared wall's two
    /// occurrences are never compared to each other (see `AAG`'s own identity guard). This checks
    /// every edge's classification directly, which is a stronger statement than the aggregate
    /// pocket count those two suites pin -- two wrongly-classified edges could in principle cancel
    /// out in the count without this per-edge check catching it.
    @Test("two boxes glued face to face have no concave edges in either compound order")
    func gluedBoxesHaveNoConcaveEdgesEitherOrder() {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
              let pieces = block.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
              pieces.count == 2,
              let orderA = Shape.compound(pieces),
              let orderB = Shape.compound(pieces.reversed())
        else {
            Issue.record("could not build the split-box fixture")
            return
        }

        #expect(orderA.buildAAG().edges.allSatisfy { $0.convexity != .concave })
        #expect(orderB.buildAAG().edges.allSatisfy { $0.convexity != .concave })
        #expect(orderA.detectPocketsAAG().count == 0)
        #expect(orderB.detectPocketsAAG().count == 0)
    }

    /// The fix corrects the SIGN CONVENTION; it does not flatten every edge to convex or smooth. A
    /// genuine pocket (real overlap between the box and the cutting tool, floor strictly inside
    /// the material -- see `OCCTModelingTests.detectPocket()`'s own doc comment for why the tool's
    /// placement matters here) still reports concave edges at the floor/wall junction.
    @Test("a genuine pocket still reports concave floor/wall edges")
    func genuinePocketStillReportsConcaveEdges() {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
              let pocket = Shape.box(origin: SIMD3(-5, -5, 0), width: 10, height: 10, depth: 15),
              let result = box.subtracting(pocket)
        else {
            Issue.record("could not build the pocketed box")
            return
        }
        // #720 review of #703, finding 5: `?? 0` on both sides would still pass if either volume
        // computation silently failed (nil), so unwrap and fail loudly instead; see
        // OCCTModelingTests.detectPocket()'s identical fix for the full reasoning.
        guard let resultVolume = result.volume, let boxVolume = box.volume else {
            #expect(Bool(false), "volume computation failed; fixture proves nothing")
            return
        }
        #expect(resultVolume < boxVolume,
                "pocket tool must actually remove material, or this fixture proves nothing")

        let aag = result.buildAAG()
        #expect(aag.edges.contains { $0.convexity == .concave })
        #expect(result.detectPocketsAAG().count == 1)
    }

    /// CHARACTERISATION TEST. It pins what this formula currently answers, which is NOT the
    /// correct answer. Do not read the pinned `2` as ground truth, and do not treat a future
    /// change of it to `0` as a regression: that change is #723 landing.
    ///
    /// The correct answer for a round through-hole is **zero** concave edges. A hole rim is
    /// convex: at the rim the solid occupies the quarter-space below the top face and outside the
    /// cylinder, so the material angle is 90 degrees, not the 270 that makes an edge concave. The
    /// concave edge of a hole is the one where a wall meets a FLOOR, and a through-hole has no
    /// floor. Measured on this exact fixture with OCCT's own classifier,
    /// `ChFi3d::DefineConnectType`, which the fillet and chamfer builders use: 15 edges, 15
    /// convex, 0 concave, at every one of the four thicknesses below.
    ///
    /// The two vocabularies do agree elsewhere, which is what makes this a defect rather than a
    /// definitional difference: on a plain box both say 12 convex and 0 concave, on the L-shape
    /// both say 19 convex and 1 concave, and the square-pocket test below pins 8 concave, which is
    /// exactly what `ChFi3d` reports for it. They diverge only here, where the centroid formula is
    /// wrong, because the direction from the rim to the cylindrical wall's area centroid is a
    /// GLOBAL property that says nothing about the LOCAL dihedral at the rim.
    ///
    /// Kept rather than deleted because it still locks out the base branch's order-dependent
    /// formula, which answered 6 here, and because pinning the current answer makes #723's effect
    /// visible in the diff instead of silent.
    @Test("a round through-hole: current formula answers two concave edges, correct answer is zero (#723)",
          arguments: [20.0, 40.0, 60.0, 120.0])
    func throughHoleConcaveCountIsPinnedPendingIssue723(thickness: Double) throws {
        let plate = try #require(Shape.box(width: 50, height: 50, depth: thickness))
        let drill = try #require(Shape.cylinder(
            at: SIMD3(0, 0, -5), direction: SIMD3(0, 0, 1), radius: 10, height: thickness + 10))
        let drilled = try #require(plate.subtracting(drill))

        let aag = drilled.buildAAG()
        let label: Comment = "thickness=\(thickness)"
        #expect(aag.edges.count == 14, label)
        // 2 is this formula's answer. ChFi3d::DefineConnectType says 0, and it is right. #723.
        #expect(aag.edges.filter { $0.convexity == .concave }.count == 2, label)
    }

    /// The curved-geometry counterpart above covers a hole; this covers a genuine blind pocket
    /// with a curved answer that IS pinned exactly, unlike the through-hole's height-dependent
    /// residual. A blind square pocket's floor meets its four walls, and its four walls meet the
    /// surrounding top face, at eight distinct concave dihedrals (material recedes at each); no
    /// other edge in the fixture is concave. This is exactly what #723's own measurement recorded
    /// for a square pocket ("concave set exact") at multiple depths, so pinning it here locks in
    /// the one part of that measurement that is not in dispute.
    @Test("a blind square pocket has exactly eight concave edges, at several depths",
          arguments: [2.0, 10.0, 25.0])
    func squarePocketHasExactlyEightConcaveEdges(depth: Double) throws {
        let box = try #require(Shape.box(width: 30, height: 30, depth: 30))
        let pocket = try #require(Shape.box(
            origin: SIMD3(-5, -5, 15 - depth), width: 10, height: 10, depth: depth + 1))
        let pocketed = try #require(box.subtracting(pocket))

        let aag = pocketed.buildAAG()
        let label: Comment = "depth=\(depth)"
        #expect(aag.edges.filter { $0.convexity == .concave }.count == 8, label)
        #expect(pocketed.detectPocketsAAG().count == 1, label)
    }
}
