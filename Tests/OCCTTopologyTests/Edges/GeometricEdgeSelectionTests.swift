import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// Issue #171: geometric edge selection for robust filleting.
@Suite("Geometric Edge Selection")
struct GeometricEdgeSelectionTests {

    /// An L-bracket built by extruding an L-shaped profile, used to exercise the
    /// concave/convex classification.
    private func lBracket() -> Shape? {
        let profile = Wire.polygon(
            [
                SIMD2(0, 0),
                SIMD2(30, 0),
                SIMD2(30, 8),
                SIMD2(8, 8),
                SIMD2(8, 30),
                SIMD2(0, 30),
            ], closed: true)
        guard let profile else { return nil }
        return Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: 20)
    }

    @Test("edges(where:) filters by predicate and keeps indices")
    func edgesWherePredicate() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let long = box.edges(where: { $0.length > 25 })
        // A 10×20×30 box has 4 edges of length 30.
        #expect(long.count == 4)
        for e in long {
            #expect(e.index >= 0)
            #expect(e.length > 25)
        }
        // Selected edges must round successfully (proves indices are usable).
        let rounded = box.filleted(edges: long, radius: 1)
        #expect(rounded != nil)
    }

    @Test("concaveEdges finds the inside corner of an L-bracket")
    func concaveEdgesLBracket() {
        guard let bracket = lBracket() else {
            Issue.record("Failed to build L-bracket")
            return
        }
        let concave = bracket.concaveEdges()
        // The reentrant inside corner is concave; only a small minority of the
        // bracket's edges are (the rest of an L-prism is convex/tangent).
        #expect(concave.count >= 1)
        #expect(concave.count < bracket.edgeCount)
        for e in concave { #expect(e.index >= 0) }

        // The whole point of issue #171: these select straight into a fillet.
        let rounded = bracket.filleted(edges: concave, radius: 2)
        #expect(rounded != nil)
        if let rounded { #expect(rounded.isValid) }
    }

    @Test("convexEdges returns the outer edges of a box")
    func convexEdgesBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let convex = box.convexEdges()
        // All 12 edges of a box are convex.
        #expect(convex.count == 12)
        #expect(box.concaveEdges().isEmpty)
    }

    @Test("edges(parallelTo:) selects the vertical edges of a prism")
    func edgesParallelToAxis() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let vertical = box.edges(parallelTo: SIMD3(0, 0, 1))
        // 4 edges run along Z (the depth, length 30).
        #expect(vertical.count == 4)
        for e in vertical { #expect(abs(e.length - 30) < 1e-6) }
        // Sign-agnostic: -Z gives the same edges.
        #expect(box.edges(parallelTo: SIMD3(0, 0, -1)).count == 4)
    }

    @Test("edges(inBounds:) selects edges within a region")
    func edgesInBounds() {
        // Shape.box is centred at the origin, so a 10-cube spans [-5, 5].
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // A region hugging the bottom (z = -5) face contains its 4 edges.
        let bottom = box.edges(inBounds: SIMD3(-6, -6, -5.1), SIMD3(6, 6, -4.9))
        #expect(bottom.count == 4)
        for e in bottom {
            #expect(e.bounds!.max.z < -4.9)
        }
        // A region covering the whole box contains every edge.
        let all = box.edges(inBounds: SIMD3(-6, -6, -6), SIMD3(6, 6, 6))
        #expect(all.count == box.edgeCount)
    }
}
