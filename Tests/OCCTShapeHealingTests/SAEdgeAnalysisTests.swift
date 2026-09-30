import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: every value below is ShapeAnalysis_Edge's own answer on the same edge and face, from
// Scripts/repro/766-healing-saedge/probe.mm. `subShapes(ofType:)` is TopExp::MapShapes order, so
// the box's first edge lies on its first face (x = -5), from (-5,-5,-5) to (-5,-5,5). Before
// #766 eight of these tests discarded the answer (`let _ =`) and every one of them returned
// early, silently green, if the box failed to build.
@Suite("ShapeAnalysis_Edge Tests")
struct SAEdgeAnalysisTests {
    private func boxEdgeAndFace() throws -> (edge: Shape, face: Shape, box: Shape) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        let face = try #require(box.subShapes(ofType: .face).first)
        return (edge, face, box)
    }

    /// The first face and that face's own first edge (the same edge as the box's first, measured).
    private func faceAndItsEdge() throws -> (edge: Shape, face: Shape) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let edge = try #require(face.subShapes(ofType: .edge).first)
        return (edge, face)
    }

    @Test func edgeHasCurve3d() throws {
        let (edge, _, _) = try boxEdgeAndFace()
        #expect(EdgeAnalysis.hasCurve3d(edge))
    }

    @Test func edgeIsClosed3d() throws {
        let (edge, _, _) = try boxEdgeAndFace()
        #expect(!EdgeAnalysis.isClosed3d(edge))
    }

    @Test func edgeHasPCurve() throws {
        // Kernel: the first edge has a pcurve on the first face.
        let (edge, face, _) = try boxEdgeAndFace()
        #expect(EdgeAnalysis.hasPCurve(edge, face: face))
    }

    @Test func edgeIsSeam() throws {
        let (edge, face, _) = try boxEdgeAndFace()
        #expect(!EdgeAnalysis.isSeam(edge, face: face))  // box edges are not seam edges
    }

    @Test func edgeSameParameter() throws {
        // ShapeAnalysis_Edge::CheckSameParameter reports a problem; kernel: none, deviation 0.
        let (edge, _, _) = try boxEdgeAndFace()
        let result = EdgeAnalysis.checkSameParameter(edge)
        #expect(result.ok == false)
        #expect(result.maxDeviation == 0)
    }

    @Test func edgeVerticesWithCurve3d() throws {
        // Kernel: no vertex/curve mismatch on a box edge.
        let (edge, _, _) = try boxEdgeAndFace()
        #expect(!EdgeAnalysis.checkVerticesWithCurve3d(edge))
    }

    // #1577: checkVerticesWithCurve3d used to default `precision` to a fixed `1e-6`, stricter than
    // ShapeAnalysis_Edge's own sentinel default (`preci < 0` checks each vertex against its OWN
    // stored tolerance instead of a fixed distance). Two straight edges whose endpoints are 0.005
    // apart, both tolerances loosened to 0.01, joined by `wireFromEdges`: the merged vertex sits
    // ~0.0025 from each edge's own curve end, inside its own tolerance but past a fixed 1e-6.
    // Kernel (probe): fixed 1e-6 flags both edges, the sentinel flags neither.
    @Test func edgeVerticesWithCurve3dSentinelDefaultUsesOwnVertexTolerance() {
        guard let edgeA = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)) else {
            Issue.record("failed to build edgeA")
            return
        }
        guard let edgeB = Shape.edgeFromPoints(SIMD3(10.005, 0, 0), SIMD3(20, 0, 0)) else {
            Issue.record("failed to build edgeB")
            return
        }
        edgeA.setTolerance(0.01)
        edgeB.setTolerance(0.01)
        guard let wire = Shape.wireFromEdges([edgeA, edgeB]) else {
            Issue.record("failed to build wire from mismatched edges")
            return
        }
        let joinedEdges = wire.subShapes(ofType: .edge)
        #expect(joinedEdges.count == 2)
        for edge in joinedEdges {
            #expect(EdgeAnalysis.checkVerticesWithCurve3d(edge, precision: 1e-6))
            #expect(!EdgeAnalysis.checkVerticesWithCurve3d(edge))
        }
    }

    @Test func edgeVerticesWithPCurve() throws {
        let (edge, face, _) = try boxEdgeAndFace()
        #expect(!EdgeAnalysis.checkVerticesWithPCurve(edge, face: face))
    }

    @Test func edgeCurve3dWithPCurve() throws {
        let (edge, face, _) = try boxEdgeAndFace()
        #expect(!EdgeAnalysis.checkCurve3dWithPCurve(edge, face: face))
    }

    @Test func edgeFirstLastVertex() throws {
        let (edge, _, _) = try boxEdgeAndFace()
        #expect(EdgeAnalysis.firstVertex(edge) == SIMD3(-5, -5, -5))
        #expect(EdgeAnalysis.lastVertex(edge) == SIMD3(-5, -5, 5))
    }

    @Test func edgeVertexTolerance() throws {
        // Kernel: no increase needed; both tolerances come back as the vertex default 1e-7.
        let (edge, face, _) = try boxEdgeAndFace()
        let r = EdgeAnalysis.checkVertexTolerance(edge, face: face)
        #expect(r.ok == false)
        #expect(abs(r.toler1 - 1e-7) < 1e-12)
        #expect(abs(r.toler2 - 1e-7) < 1e-12)
    }

    @Test func edgeCheckOverlapping() throws {
        let (_, _, box) = try boxEdgeAndFace()
        let edges = box.subShapes(ofType: .edge)
        try #require(edges.count >= 2)
        let result = EdgeAnalysis.checkOverlapping(edges[0], edges[1])
        #expect(!result.overlapping)
    }

    // #1438: OCCTEdgeCheckOverlapping used to zero its own `tolOverlap` right before passing it to
    // ShapeAnalysis_Edge::CheckOverlapping, which reads it as an INPUT threshold, so it always
    // returned false -- even for an edge checked against itself.
    @Test func edgeCheckOverlappingDetectsRealOverlap() throws {
        let (edge, _, _) = try boxEdgeAndFace()
        // An edge always overlaps itself.
        let result = EdgeAnalysis.checkOverlapping(edge, edge)
        #expect(result.overlapping)
        #expect(result.tolerance > 0)
    }

    @Test func edgeBoundUV() throws {
        let (edge, face) = try faceAndItsEdge()
        let bounds = try #require(EdgeAnalysis.boundUV(edge, face: face))
        #expect(bounds.uFirst == 0 && bounds.vFirst == 0)
        #expect(bounds.uLast == 10 && bounds.vLast == 0)
    }

    @Test func edgeEndTangent2d() throws {
        let (edge, face) = try faceAndItsEdge()
        let tang = try #require(EdgeAnalysis.endTangent2d(edge, face: face, atEnd: false))
        #expect(simd_distance(tang.point, SIMD2(0, 0)) < 1e-12)
        #expect(simd_distance(tang.tangent, SIMD2(1, 0)) < 1e-12)
    }

    @Test func edgePCurveRange() throws {
        let (edge, face) = try faceAndItsEdge()
        #expect(EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: 10))
    }

    // #1438: OCCTEdgeCheckPCurveRange used to compare [first, last] against the edge's own
    // CURRENT STORED TRIM on the face, rather than the pcurve's own underlying geometric domain.
    // Kernel: [0, pi] is inside the circle pcurve's period (true), [0, 2 pi + 0.5] is not.
    @Test func edgePCurveRangeChecksPCurveDomainNotEdgeTrim() {
        guard let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("failed to build cylindrical surface")
            return
        }
        guard let pcurve = Curve2D.circle(center: SIMD2(0, 5), radius: 3) else {
            Issue.record("failed to build periodic 2D pcurve")
            return
        }
        guard
            let edge = Shape.edgeOnSurface(pcurve: pcurve, surface: surface, u1: 0, u2: .pi / 2)
        else {
            Issue.record("failed to build edge on surface")
            return
        }
        guard let face = Shape.face(from: surface, uRange: 0...(2 * .pi), vRange: 0...10) else {
            Issue.record("failed to build face from surface")
            return
        }
        #expect(EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: .pi))
        #expect(!EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: 2 * .pi + 0.5))
    }
}
