import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill CoonsAlgPatch")
struct GeomFillCoonsAlgPatchTests {
    @Test("Coons algorithmic patch from edges")
    func coonsAlgPatch() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard edges.count >= 4 else { return }
        let result = Shape.coonsAlgPatch(
            edge1: edges[0], edge2: edges[1],
            edge3: edges[2], edge4: edges[3],
            evalU: 5, evalV: 5
        )
        #expect(result != nil)
        if let result = result {
            #expect(result.count == 25)  // 5x5 grid
        }
    }

    /// #1499: `OCCTGeomFillCoonsAlgPatchEval` never called `GeomFill_SimpleBound::Reparametrize()`
    /// before evaluating the resulting `GeomFill_CoonsAlgPatch` at `u,v` normalized to `[0,1]`, so
    /// it silently sampled only a tiny sliver of the patch near each edge's own raw parameter
    /// origin. This is the issue's own fixture: a non-unit-scale (10x10) planar square, edges
    /// wound loop-order (bottom -> right -> top -> left, each edge authored continuing the
    /// previous one's endpoint, matching how a real wire's edges are typically handed to this
    /// API). Before the fix, `patch.Value(0.5, 0.5)` landed near `(0.5, 0.5, 0)` (half a raw
    /// curve-parameter unit from the first corner) instead of the square's real center.
    @Test("Center of a non-unit-scale square patch is the real center, not a raw-parameter artifact")
    func centerLandsAtRealCenterNotRawParameterSliver() {
        let c0 = SIMD3<Double>(0, 0, 0)
        let c1 = SIMD3<Double>(10, 0, 0)
        let c2 = SIMD3<Double>(10, 10, 0)
        let c3 = SIMD3<Double>(0, 10, 0)

        guard let bottom = Shape.edgeFromPoints(c0, c1),  // c0 -> c1
            let right = Shape.edgeFromPoints(c1, c2),  // c1 -> c2
            let top = Shape.edgeFromPoints(c2, c3),  // c2 -> c3
            let left = Shape.edgeFromPoints(c3, c0)  // c3 -> c0, closes the loop
        else {
            Issue.record("Failed to build the square's 4 boundary edges")
            return
        }

        // evalU = evalV = 3 puts grid points at u,v in {0, 0.5, 1}; index 4 (i=1,j=1) is the
        // center (u=0.5, v=0.5), index 0 (i=0,j=0) and index 8 (i=2,j=2) are the two corners
        // the issue's own verification checked.
        guard
            let result = Shape.coonsAlgPatch(
                edge1: bottom, edge2: right, edge3: top, edge4: left,
                evalU: 3, evalV: 3)
        else {
            Issue.record("coonsAlgPatch returned nil")
            return
        }
        #expect(result.count == 9)

        let nearCorner = result[0]
        let center = result[4]
        let farCorner = result[8]

        #expect(simd_length(nearCorner - c0) < 1e-6)
        #expect(simd_length(center - SIMD3<Double>(5, 5, 0)) < 1e-6)
        #expect(simd_length(farCorner - c2) < 1e-6)
    }
}
