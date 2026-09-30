import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: every value below is ShapeAnalysis_Wire's own answer on the same wire, face and precision
// (1e-6), from Scripts/repro/766-healing-sawire-263/probe.mm: the box's first mapped face (x = -5)
// and its first mapped wire. Before #766 five of these discarded their answers (`let _ =`), two
// asserted `>= 0` on distances, and all returned early, silently green, if the box failed.
//
// Several checks report a "problem" on this healthy box face (order, 3D/2D gaps, edge curves, the
// gap at edge 1) with gap distances of 14.14 = 10 sqrt 2, a diagonal. The kernel does that on the
// face's own wire and on the same wire re-oriented FORWARD (probe); it is pinned as measured and
// flagged in the PR as a finding to understand, not asserted as correct behaviour.
@Suite("ShapeAnalysis_Wire Tests")
struct SAWireAnalysisTests {
    private func faceAndWire() throws -> (face: Shape, wire: Shape) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let wire = try #require(face.subShapes(ofType: .wire).first)
        return (face, wire)
    }

    @Test func basicWireChecks() throws {
        let (face, wire) = try faceAndWire()
        #expect(SAWireAnalysis.checkOrder(wire: wire, face: face) == true)
        #expect(SAWireAnalysis.checkConnected(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkSmall(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkDegenerated(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkClosed(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkGaps3d(wire: wire, face: face) == true)
    }

    @Test func wireEdgeCount() throws {
        let (face, wire) = try faceAndWire()
        #expect(SAWireAnalysis.edgeCount(wire: wire, face: face) == 4)
    }

    @Test func wireDistance3d() throws {
        let (face, wire) = try faceAndWire()
        #expect(abs(SAWireAnalysis.minDistance3d(wire: wire, face: face) - 14.142135624) < 1e-6)
        #expect(abs(SAWireAnalysis.maxDistance3d(wire: wire, face: face) - 14.142135624) < 1e-6)
    }

    @Test func wireDistance2d() throws {
        let (face, wire) = try faceAndWire()
        #expect(abs(SAWireAnalysis.minDistance2d(wire: wire, face: face) - 14.142135624) < 1e-6)
        #expect(abs(SAWireAnalysis.maxDistance2d(wire: wire, face: face) - 14.142135624) < 1e-6)
    }

    @Test func wireSelfIntersection() throws {
        let (face, wire) = try faceAndWire()
        #expect(!SAWireAnalysis.checkSelfIntersection(wire: wire, face: face))
    }

    @Test func wireEdgeCurves() throws {
        let (face, wire) = try faceAndWire()
        #expect(SAWireAnalysis.checkEdgeCurves(wire: wire, face: face) == true)
        #expect(SAWireAnalysis.checkLacking(wire: wire, face: face) == false)
    }

    @Test func wirePerEdgeChecks() throws {
        let (face, wire) = try faceAndWire()
        #expect(SAWireAnalysis.checkConnectedEdge(wire: wire, face: face, edgeIndex: 1) == false)
        #expect(SAWireAnalysis.checkSmallEdge(wire: wire, face: face, edgeIndex: 1) == false)
        #expect(SAWireAnalysis.checkDegeneratedEdge(wire: wire, face: face, edgeIndex: 1) == false)
        #expect(SAWireAnalysis.checkGap3dEdge(wire: wire, face: face, edgeIndex: 1) == true)
    }

    @Test func wireGaps2d() throws {
        let (face, wire) = try faceAndWire()
        #expect(SAWireAnalysis.checkGaps2d(wire: wire, face: face) == true)
    }

    @Test func outerBound() throws {
        // True means "problem found", matching every sibling. A box face's own wire is its outer
        // bound, so there is no problem to report (#999). False rather than nil, since nil is now
        // reserved for a check that could not run (#1058).
        let (face, wire) = try faceAndWire()
        #expect(SAWireAnalysis.checkOuterBound(wire: wire, face: face) == false)
    }
}
