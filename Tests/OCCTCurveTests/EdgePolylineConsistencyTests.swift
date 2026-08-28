import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Edge Polyline Consistency Tests")
struct EdgePolylineConsistencyTests {

    @Test("Lofted shape edge polylines match edge count")
    func loftedShapeEdgePolylines() {
        // Two circles at different Z heights
        guard let circle1 = Wire.circle(radius: 10),
            let circle2 = Wire.circle(radius: 5)
        else {
            Issue.record("Failed to create circle wires")
            return
        }
        // Loft between the two circles
        let lofted = Shape.loft(profiles: [circle1, circle2], solid: true)!
        #expect(lofted.isValid)

        let edgeCount = lofted.edgeCount
        #expect(edgeCount > 0)

        let polylines = lofted.allEdgePolylines(deflection: 0.1)
        #expect(
            polylines.count == edgeCount,
            "polylines.count (\(polylines.count)) should match edgeCount (\(edgeCount))")

        // Every edge should produce at least 2 points
        for (i, polyline) in polylines.enumerated() {
            #expect(
                polyline.count >= 2,
                "Edge \(i) should have at least 2 points, got \(polyline.count)")
        }
    }

    @Test("Extruded rectangle all 12 edges recovered")
    func extrudedRectangleEdges() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }
        let solid = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 8)!
        #expect(solid.isValid)

        // A box-like extrusion has 12 edges
        let edgeCount = solid.edgeCount
        #expect(edgeCount == 12, "Extruded rectangle should have 12 edges, got \(edgeCount)")

        let polylines = solid.allEdgePolylines(deflection: 0.1)
        #expect(
            polylines.count == 12, "Should recover all 12 edge polylines, got \(polylines.count)")
    }

    @Test("Extruded circle seam edges handled")
    func extrudedCircleEdges() {
        guard let circle = Wire.circle(radius: 5) else {
            Issue.record("Failed to create circle wire")
            return
        }
        let solid = Shape.extrude(profile: circle, direction: SIMD3(0, 0, 1), length: 10)!
        #expect(solid.isValid)

        let edgeCount = solid.edgeCount
        #expect(edgeCount > 0)

        let polylines = solid.allEdgePolylines(deflection: 0.1)
        #expect(
            polylines.count == edgeCount,
            "polylines.count (\(polylines.count)) should match edgeCount (\(edgeCount))")

        for (i, polyline) in polylines.enumerated() {
            #expect(
                polyline.count >= 2,
                "Edge \(i) should have at least 2 points, got \(polyline.count)")
        }
    }

    @Test("allEdgePolylines count matches edgeCount for various shapes")
    func consistencyAcrossShapes() {
        let shapes: [(String, Shape)] = [
            ("box", Shape.box(width: 5, height: 5, depth: 5)!),
            ("cylinder", Shape.cylinder(radius: 3, height: 6)!),
        ]

        for (name, shape) in shapes {
            let edgeCount = shape.edgeCount
            let polylines = shape.allEdgePolylines(deflection: 0.1)
            #expect(
                polylines.count == edgeCount,
                "\(name): polylines.count (\(polylines.count)) != edgeCount (\(edgeCount))")
        }

        // Sphere has degenerate edges (poles) that are correctly skipped
        let sphere = Shape.sphere(radius: 4)!
        let spherePolylines = sphere.allEdgePolylines(deflection: 0.1)
        #expect(spherePolylines.count >= 1, "Sphere should have at least the equator edge")
        #expect(spherePolylines.count <= sphere.edgeCount)
    }
}
