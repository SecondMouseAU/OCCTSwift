import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// An edge built from a pcurve on a cylinder, so it has no 3D curve until one is built.
private func pcurveOnlyEdge() -> Shape? {
    guard
        let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 10),
        let pcurve = Curve2D.line(through: SIMD2(0.2, -3), direction: SIMD2(0.6, 0.8))
    else { return nil }
    return Shape.edgeOnSurface(pcurve: pcurve, surface: cylinder, u1: 0, u2: 2)
}

@Suite("BRepTools/BRepLib Utilities Tests")
struct BRepToolsUtilitiesTests {

    @Test func clean() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        func meshed() -> Int {
            edges.filter { Shape.polygonOnTriangulation(edge: $0) != nil }.count
        }
        _ = box.mesh(linearDeflection: 0.5)
        #expect(meshed() == 12)
        // Clean removes all tessellation data, and nothing else.
        box.clean()
        #expect(meshed() == 0)
        #expect(box.isValid)
        #expect(abs((box.volume ?? 0) - 1000) < 1e-6)
        #expect(edges.allSatisfy { $0.extractEdgeCurve3D() != nil })
    }

    @Test func cleanGeometry() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(edges.allSatisfy { $0.extractEdgeCurve3D() != nil })
        // Geometry is removed outright: no edge keeps a 3D curve, and the topology stays.
        box.cleanGeometry()
        #expect(edges.allSatisfy { $0.extractEdgeCurve3D() == nil })
        #expect(box.subShapes(ofType: .edge).count == 12)
        #expect(box.subShapes(ofType: .face).count == 6)
    }

    @Test func removeUnusedPCurves() throws {
        // The edge's only representation is a pcurve on a surface no face uses, so it is unused
        // and removed. Observed through buildCurves3d, which needs some representation to build
        // from: it is true for the untouched control and false once the pcurve is gone.
        let control = try #require(pcurveOnlyEdge())
        #expect(control.extractEdgeCurve3D() == nil)
        #expect(control.buildCurves3d())
        #expect(control.extractEdgeCurve3D() != nil)

        let stripped = try #require(pcurveOnlyEdge())
        stripped.removeUnusedPCurves()
        #expect(!stripped.buildCurves3d())
        #expect(stripped.extractEdgeCurve3D() == nil)

        // On a solid whose every pcurve is on a face's own surface nothing is removed.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        box.removeUnusedPCurves()
        #expect(box.isValid)
        #expect(abs((box.volume ?? 0) - 1000) < 1e-6)
    }

    @Test func updateShape() throws {
        // BRepTools::Update refreshes the bounds and leaves tolerances as they are.
        let shape = try #require(boxWithLooseEdges())
        shape.updateShape()
        #expect(shape.isValid)
        #expect(abs(shape.maxEdgeTolerance - 0.5) < 1e-12)
        #expect(abs(shape.maxVertexTolerance - 1e-7) < 1e-12)
        #expect(abs((shape.volume ?? 0) - 1000) < 1e-6)
        #expect(shape.subShapes(ofType: .edge).count == 12)
    }

    @Test func updateTolerances() throws {
        // A vertex must cover the edges that end on it. With the edges at 0.5 and the vertices
        // at 1e-7, updating raises the vertices to the edges' tolerance and lowers nothing.
        let shape = try #require(boxWithLooseEdges())
        #expect(abs(shape.maxVertexTolerance - 1e-7) < 1e-12)
        shape.updateTolerances()
        #expect(abs(shape.maxVertexTolerance - 0.5) < 1e-9)
        #expect(abs(shape.maxEdgeTolerance - 0.5) < 1e-12)
        #expect(abs(shape.maxFaceTolerance - 1e-7) < 1e-12)

        // A box already consistent at 1e-7 stays there.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        box.updateTolerances()
        #expect(abs(box.maxVertexTolerance - 1e-7) < 1e-12)
        #expect(abs(box.maxEdgeTolerance - 1e-7) < 1e-12)
    }

    @Test func updateInnerTolerances() throws {
        // Same set-up: the vertices are raised to the loose edges they end.
        let shape = try #require(boxWithLooseEdges())
        #expect(abs(shape.maxVertexTolerance - 1e-7) < 1e-12)
        shape.updateInnerTolerances()
        #expect(abs(shape.maxVertexTolerance - 0.5) < 1e-9)
        #expect(abs(shape.maxEdgeTolerance - 0.5) < 1e-12)
        #expect(shape.isValid)

        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        box.updateInnerTolerances()
        #expect(abs(box.maxVertexTolerance - 1e-7) < 1e-12)
        #expect(abs(box.maxEdgeTolerance - 1e-7) < 1e-12)
    }

    @Test func buildCurve3d() throws {
        // An edge that already has its 3D curve is left as it is: true, the curve still there,
        // still 10 long.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let boxEdge = try #require(box.subShapes(ofType: .edge).first)
        #expect(Shape.buildCurve3d(edge: boxEdge))
        #expect(boxEdge.extractEdgeCurve3D() != nil)
        #expect(abs(boxEdge.totalEdgeLength - 10) < 1e-9)

        // An edge with only a pcurve gets one: nil before, a curve after, tolerance at the
        // requested 1e-6.
        let edge = try #require(pcurveOnlyEdge())
        #expect(edge.extractEdgeCurve3D() == nil)
        #expect(Shape.buildCurve3d(edge: edge, tolerance: 1e-6))
        #expect(edge.extractEdgeCurve3D() != nil)
        #expect(abs(edge.edgeTolerance - 1e-6) < 1e-12)
    }

    @Test func checkSameRange() throws {
        // Every edge of a box has its pcurve over the 3D curve's own range.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(edges.allSatisfy { Shape.checkSameRange(edge: $0) })

        // One pcurve cut short (range 0...9 over a 0...10 curve) is not same-range.
        let plane = try #require(Shape.faceFromPlane(uBounds: 0...10, vBounds: 0...10))
        let brep = try #require(plane.toBREPString())
        let edited = brep.replacingOccurrences(of: "2  1 1 0 0 10", with: "2  1 1 0 0 9")
        #expect(edited != brep)
        let short = try #require(Shape.fromBREPString(edited))
        let shortEdges = short.subShapes(ofType: .edge)
        #expect(shortEdges.count == 4)
        #expect(shortEdges.filter { !Shape.checkSameRange(edge: $0) }.count == 1)
    }

    @Test func sameRange() throws {
        // Already same-range: true, and still true after.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.subShapes(ofType: .edge).first)
        #expect(Shape.sameRange(edge: edge))
        #expect(Shape.checkSameRange(edge: edge))

        // The cut-short pcurve is repaired: not same-range before, same-range after.
        let plane = try #require(Shape.faceFromPlane(uBounds: 0...10, vBounds: 0...10))
        let brep = try #require(plane.toBREPString())
        let short = try #require(
            Shape.fromBREPString(
                brep.replacingOccurrences(of: "2  1 1 0 0 10", with: "2  1 1 0 0 9")))
        let broken = try #require(
            short.subShapes(ofType: .edge).first { !Shape.checkSameRange(edge: $0) })
        #expect(Shape.sameRange(edge: broken))
        #expect(Shape.checkSameRange(edge: broken))
    }

    @Test func updateEdgeTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                // A box edge's pcurves match its 3D curve exactly, so the measurement has nothing
                // to move. Issue1639UpdateEdgeToleranceTests is where the bounds are exercised.
                let update = Shape.updateEdgeTolerance(edge: edge, tolerance: 1e-4)
                #expect(update?.changed == false)
            }
        }
    }
}
