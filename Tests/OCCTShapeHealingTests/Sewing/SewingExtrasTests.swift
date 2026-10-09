import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are BRepBuilderAPI_Sewing's own answers on the same inputs, from
// Scripts/repro/766-healing-sewing/probe.mm (transcript.txt beside it).
// Before #766 the count test asserted `>= 0`, and all three used a box, which has no multiple
// edges, so the index accessor was only ever asked for an edge that does not exist. The
// non-manifold fixture here has one: three faces meeting on the edge (0,0,0)-(10,0,0).
private func threeFacesOnOneEdge() throws -> SewingBuilder {
    func quad(_ p: [SIMD3<Double>]) throws -> Shape {
        let wire = try #require(Wire.polygon3D(p, closed: true))
        return try #require(Shape.face(from: wire))
    }
    let s = try #require(SewingBuilder(tolerance: 1e-6))
    s.setNonManifoldMode(true)
    s.add(try quad([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)]))
    s.add(try quad([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, -10, 0), SIMD3(0, -10, 0)]))
    s.add(try quad([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 0, 10), SIMD3(0, 0, 10)]))
    s.perform()
    return s
}

@Suite("Sewing_Extras")
struct SewingExtrasTests {
    @Test func multipleEdgeCount() throws {
        // Kernel: NbMultipleEdges() == 1 on the three-face fixture.
        let s = try threeFacesOnOneEdge()
        #expect(s.multipleEdgeCount == 1)
        #expect(s.multipleEdge(at: 1) != nil)
    }

    @Test func noMultipleEdgesForBox() throws {
        let s = try #require(SewingBuilder(tolerance: 1e-6))
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        s.add(b)
        s.perform()
        #expect(s.multipleEdgeCount == 0)
    }

    @Test func multipleEdgeAtInvalidIndex() throws {
        // One multiple edge: index 1 exists, 2 and 999 do not.
        let s = try threeFacesOnOneEdge()
        #expect(s.multipleEdge(at: 1) != nil)
        #expect(s.multipleEdge(at: 2) == nil)
        #expect(s.multipleEdge(at: 999) == nil)
    }
}
