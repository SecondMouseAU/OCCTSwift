import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shape.fromEdge, Issue #45") struct ShapeFromEdgeTests {
    @Test("Shape.fromEdge converts edge to shape")
    func edgeToShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        #expect(edges.count == 12)
        let firstEdge = try #require(edges.first)
        let shape = try #require(Shape.fromEdge(firstEdge))
        #expect(shape.isValid)
        #expect(shape.shapeType == .edge)
        // The same edge: one 10-long edge between two vertices.
        #expect(abs(shape.totalEdgeLength - 10) < 1e-9)
        #expect(shape.vertices().count == 2)
    }

    @Test("anaFillet with Edge parameters")
    func anaFilletWithEdges() throws {
        let wire = try #require(
            Wire.polygon([SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)]))
        let edges = wire.edges()
        #expect(edges.count == 3)
        let result = try #require(
            Shape.anaFillet(edge1: edges[0], edge2: edges[1], radius: 1.0))
        // A radius-1 quarter arc at the corner (10, 0): pi / 2 long, tangent points 1 in from
        // the corner on each leg, so both legs are trimmed from 10 to 9.
        #expect(abs(result.fillet.totalEdgeLength - Double.pi / 2) < 1e-9)
        #expect(abs(result.edge1.totalEdgeLength - 9) < 1e-9)
        #expect(abs(result.edge2.totalEdgeLength - 9) < 1e-9)
        let box = try #require(result.fillet.boundingBox)
        #expect(vectorLength(box.min - SIMD3(9, 0, 0)) < 1e-5)
        #expect(vectorLength(box.max - SIMD3(10, 1, 0)) < 1e-5)
    }

    @Test("anaFillet with Wire parameter")
    func anaFilletWithWire() throws {
        let wire = try #require(
            Wire.polygon([SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)]))
        let result = try #require(Shape.anaFillet(wire: wire, radius: 1.0))
        // The first two edges of the wire, so the same corner as the Edge overload.
        #expect(abs(result.fillet.totalEdgeLength - Double.pi / 2) < 1e-9)
        #expect(abs(result.edge1.totalEdgeLength - 9) < 1e-9)
        #expect(abs(result.edge2.totalEdgeLength - 9) < 1e-9)
        // A radius larger than the legs cannot be placed.
        #expect(Shape.anaFillet(wire: wire, radius: 20.0) == nil)
    }

    @Test("filletAlgo with Edge parameters")
    func filletAlgoWithEdges() throws {
        let wire = try #require(
            Wire.polygon([SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)]))
        let edges = wire.edges()
        #expect(edges.count == 3)
        let result = try #require(
            Shape.filletAlgo(edge1: edges[0], edge2: edges[1], radius: 1.0))
        // The same corner as anaFillet, found iteratively: the legs come out 9 to about 1e-7.
        #expect(abs(result.fillet.totalEdgeLength - Double.pi / 2) < 1e-6)
        #expect(abs(result.edge1.totalEdgeLength - 9) < 1e-6)
        #expect(abs(result.edge2.totalEdgeLength - 9) < 1e-6)
        let box = try #require(result.fillet.boundingBox)
        #expect(vectorLength(box.min - SIMD3(9, 0, 0)) < 1e-5)
        #expect(vectorLength(box.max - SIMD3(10, 1, 0)) < 1e-5)
    }

    @Test("filletAlgo with Wire parameter")
    func filletAlgoWithWire() throws {
        let wire = try #require(
            Wire.polygon([SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10)]))
        let result = try #require(Shape.filletAlgo(wire: wire, radius: 1.0))
        #expect(abs(result.fillet.totalEdgeLength - Double.pi / 2) < 1e-6)
        #expect(abs(result.edge1.totalEdgeLength - 9) < 1e-6)
        #expect(abs(result.edge2.totalEdgeLength - 9) < 1e-6)
    }
}
