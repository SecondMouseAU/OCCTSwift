import Testing
import Foundation
@testable import OCCTSwift

/// #695: `concaveEdges()` / `convexEdges()` misclassified every edge after the first repeated
/// occurrence, because the bridge classifier walked a bare `TopExp_Explorer` (one entry per
/// topology *occurrence*) while the Swift layer zips that array against `edges()` (one entry per
/// *distinct* edge, `TopExp::MapShapes`). A 20 mm box has 24 edge occurrences over 12 edges, so
/// the two enumerations desynchronise from the first repeat onwards.
///
/// Measured before the fix, on the issue's own shapes: the L-prism's single reentrant corner
/// (map index 7) was reported convex, while map indices 9 and 12 -- two 45 mm edges lying in the
/// z = 40 top cap, both genuinely convex -- were reported concave. `edgeConcavityCount(.convex)`
/// answered 24 for a 12-edge box.
@Suite("Issue 695 — concave/convex edge classification")
struct Issue695ConcaveEdgeTests {

    /// The issue's L: one reentrant edge, the inside corner running along the extrusion axis.
    private static func lPrism() -> Shape? {
        guard let profile = Wire.polygon([SIMD2(0, 0), SIMD2(50, 0), SIMD2(50, 5),
                                          SIMD2(5, 5), SIMD2(5, 50), SIMD2(0, 50)]) else { return nil }
        return Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: 40)
    }

    /// The issue's T: two reentrant edges, both along the extrusion axis.
    private static func tPrism() -> Shape? {
        guard let profile = Wire.polygon([SIMD2(0, 0), SIMD2(30, 0), SIMD2(30, 10), SIMD2(20, 10),
                                          SIMD2(20, 40), SIMD2(10, 40), SIMD2(10, 10),
                                          SIMD2(0, 10)]) else { return nil }
        return Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: 20)
    }

    @Test("an L-prism has exactly one concave edge, and it is the reentrant corner")
    func lPrismHasOneConcaveEdge() throws {
        let prism = try #require(Self.lPrism())

        let concave = prism.concaveEdges()
        #expect(concave.count == 1, "expected the one inside corner, got \(concave.count)")

        // The reentrant edge runs the full extrusion height at (x, y) = (5, 5). Before the fix
        // this named two 45 mm edges in the z = 40 cap instead.
        if let corner = concave.first {
            #expect(abs(corner.length - 40) < 1e-6,
                    "the inside corner spans the extrusion height, got length \(corner.length)")
        }

        // Every edge is classified exactly once, so the two sets partition edges().
        #expect(concave.count + prism.convexEdges().count == prism.edgeCount)
    }

    @Test("a T-prism has exactly two concave edges, both reentrant corners")
    func tPrismHasTwoConcaveEdges() throws {
        let prism = try #require(Self.tPrism())

        let concave = prism.concaveEdges()
        #expect(concave.count == 2, "expected two inside corners, got \(concave.count)")
        for e in concave {
            #expect(abs(e.length - 20) < 1e-6,
                    "each inside corner spans the extrusion height, got length \(e.length)")
        }
    }

    @Test("a box has no concave edges and all twelve are convex")
    func boxIsAllConvex() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        #expect(box.concaveEdges().isEmpty)
        #expect(box.convexEdges().count == 12)
    }

    /// The count entry point had the same root cause on its own terms: it counted occurrences,
    /// so a 12-edge box reported 24 convex edges.
    @Test("concavity counts count distinct edges, not topology occurrences")
    func countsAreEdgeCountsNotOccurrenceCounts() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        #expect(box.edgeConcavityCount(.convex) == 12)
        #expect(box.edgeConcavityCount(.concave) == 0)

        let prism = try #require(Self.lPrism())
        #expect(prism.edgeConcavityCount(.concave) == 1)
        #expect(prism.edgeConcavityCount(.convex) == 17)

        // The counter and the classifier must describe the same edges.
        let pairs = try #require(prism.edgeConcavities())
        #expect(prism.edgeConcavityCount(.concave) == pairs.filter { $0.1 == .concave }.count)
        #expect(prism.edgeConcavityCount(.convex) == pairs.filter { $0.1 == .convex }.count)
    }

    /// The headline use case from #171: select the inside corner geometrically and fillet it.
    /// Before the fix the returned edges were bounded by the 5 mm leg thickness, so any radius
    /// above that failed and the fillet never applied to the corner it was aimed at.
    @Test("the concave edge fillets, and filleting it adds material")
    func concaveEdgeFilletsAndAddsMaterial() throws {
        let prism = try #require(Self.lPrism())
        let concave = prism.concaveEdges()
        let before = try #require(prism.volume)

        let rounded = try #require(prism.filleted(edges: concave, radius: 8),
                                   "a radius well above the 5 mm leg thickness must still fillet")
        #expect(rounded.isValid)

        // A concave fillet adds material: r^2 * (1 - pi/4) * width.
        let after = try #require(rounded.volume)
        let expected = 8.0 * 8.0 * (1 - Double.pi / 4) * 40
        #expect(abs((after - before) - expected) < 0.01 * expected,
                "expected about +\(expected) mm3, got \(after - before)")
    }
}
