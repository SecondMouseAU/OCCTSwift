import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire 2D Chamfer Tests")
struct Wire2DChamferTests {

    @Test("Chamfer single vertex of rectangle")
    func chamferSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Chamfer all vertices of rectangle")
    func chamferAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamferedAll2D(distance: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Asymmetric chamfer")
    func asymmetricChamfer() {
        guard let rect = Wire.rectangle(width: 20, height: 10) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        // Asymmetric chamfer: different distances
        let chamfered = rect.chamfered2D(vertexIndex: 1, distance1: 1.0, distance2: 2.0)

        #expect(chamfered != nil)
    }

    // MARK: - #1478 Finding 2: adjacency must follow wire connection order, not TopExp::MapShapes order

    /// Regression for issue #1478, Finding 2. `OCCTWireChamferAll2D` used to pair
    /// `TopExp::MapShapes(TopAbs_EDGE)` indices `(i, (i % N) + 1)` as "adjacent", but that map
    /// returns edges in stored (insertion) order, not connection order.
    ///
    /// This fixture builds a square one edge at a time via `Wire.wireFromEdges`, added
    /// deliberately out of connection order (`B-C`, then `A-B` -- which attaches to `B-C`'s
    /// FREE START rather than extending its free end -- then `C-D`, then `D-A`). That makes
    /// `TopExp::MapShapes` return `[BC, AB, CD, DA]` (insertion order) while
    /// `BRepTools_WireExplorer` returns `[BC, CD, DA, AB]` (true connection order): a genuine
    /// reordering, not merely a rotation, so pairing consecutive `TopExp::MapShapes` indices
    /// only ever finds the 2 adjacent pairs at corners B and D -- the map-consecutive pairs
    /// at corners A and C (`AB`+`CD`, `DA`+`BC`) share no vertex at all and were silently
    /// skipped.
    ///
    /// Verified directly against the real `ChFi2d_Builder` algorithm
    /// (`Scripts/repro/1478-healing-blends-defects/find_chamfer_fixture.mm`): with the pre-fix
    /// `TopExp::MapShapes` pairing, this exact fixture chamfers only 2 of the 4 corners (6
    /// result edges); with the `BRepTools_WireExplorer`-based fix, it correctly finds and
    /// chamfers all 4 adjacent pairs (8 result edges).
    @Test("chamferedAll2D pairs edges by true wire connection order, not TopExp::MapShapes insertion order")
    func chamferAllUsesWireConnectionOrderNotMapOrder() throws {
        let a = SIMD3<Double>(0, 0, 0)
        let b = SIMD3<Double>(10, 0, 0)
        let c = SIMD3<Double>(10, 10, 0)
        let d = SIMD3<Double>(0, 10, 0)

        let edgeAB = try #require(Wire.line(from: a, to: b)?.edges().first)
        let edgeBC = try #require(Wire.line(from: b, to: c)?.edges().first)
        let edgeCD = try #require(Wire.line(from: c, to: d)?.edges().first)
        let edgeDA = try #require(Wire.line(from: d, to: a)?.edges().first)

        // Add order: BC, AB, CD, DA -- AB attaches to BC's free start, not its free end.
        let wire = try #require(Wire.wireFromEdges([edgeBC, edgeAB, edgeCD, edgeDA]))
        #expect(wire.edges().count == 4)

        let chamfered = try #require(wire.chamferedAll2D(distance: 1.0))

        // All four corners chamfered: 4 original edges + 4 new chamfer edges. The pre-fix
        // TopExp::MapShapes pairing would have chamfered only corners B and D (6 edges).
        #expect(chamfered.edges().count == 8)
    }
}
