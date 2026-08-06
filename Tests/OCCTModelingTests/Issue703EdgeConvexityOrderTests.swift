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
        #expect((result.volume ?? 0) < (box.volume ?? 0),
                "pocket tool must actually remove material, or this fixture proves nothing")

        let aag = result.buildAAG()
        #expect(aag.edges.contains { $0.convexity == .concave })
        #expect(result.detectPocketsAAG().count == 1)
    }
}
