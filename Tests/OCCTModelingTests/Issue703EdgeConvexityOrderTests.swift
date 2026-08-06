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

    /// #720's automated review of this PR (findings 1 and 6) is right that every fixture above is
    /// planar and axis-aligned, and that the replacement formula (each face's own area centroid,
    /// a GLOBAL property, standing in for a LOCAL one) is not exact everywhere: #723 tracks a
    /// measured case (a through-hole rim) where the answer drifts with plate thickness, and that
    /// residual is deliberately NOT fixed here. But "not exact everywhere" is not "untested on
    /// curved/holed geometry": a plain round through-hole has an unambiguous ground truth, namely
    /// exactly two concave edges, where the cylindrical wall meets the top and bottom faces, and
    /// nothing else, independent of plate thickness, since the wall is one full-period
    /// cylindrical face with no vertical seam. This fixture (50mm square plate, 10mm-radius hole)
    /// does not trip #723's drift at any of the four thicknesses tried, including the two
    /// (20, 40) that bracket where #723's own fixture drifted, so it is a real regression lock
    /// against the base branch's formula, not a restatement of the known residual.
    @Test("a round through-hole has exactly two concave edges, at several plate thicknesses",
          arguments: [20.0, 40.0, 60.0, 120.0])
    func throughHoleHasExactlyTwoConcaveEdges(thickness: Double) throws {
        let plate = try #require(Shape.box(width: 50, height: 50, depth: thickness))
        let drill = try #require(Shape.cylinder(
            at: SIMD3(0, 0, -5), direction: SIMD3(0, 0, 1), radius: 10, height: thickness + 10))
        let drilled = try #require(plate.subtracting(drill))

        let aag = drilled.buildAAG()
        let label: Comment = "thickness=\(thickness)"
        #expect(aag.edges.count == 14, label)
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
