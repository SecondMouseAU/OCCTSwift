import Testing
import simd

@testable import OCCTSwift

// MARK: - Edge Polyline Tests (Issue #29)

@Suite("Edge Polylines, Lofted and Extruded Shapes")
struct EdgePolylineTests {
    @Test("Box edge polylines returns all 12 edges")
    func boxEdgePolylines() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let polylines = box.allEdgePolylines()
        #expect(polylines.count == 12)
        for poly in polylines {
            #expect(poly.count >= 2)
        }
    }

    @Test("Lofted solid returns edge polylines")
    func loftedEdgePolylines() {
        // Loft between two rectangles of different sizes
        let bottom = Wire.rectangle(width: 10, height: 10)!
        let top = Wire.rectangle(width: 5, height: 5)!
        let lofted = Shape.loft(profiles: [bottom, top])
        #expect(lofted != nil)
        guard let shape = lofted else { return }

        let edgeCount = shape.edges().count
        #expect(edgeCount > 0)

        // A loft that silently used only `bottom` (ignoring `top`) would still be a valid
        // 4-edge, 1-face shape and would pass every check below: a genuine loft between two
        // differently-sized closed wires has more than one face (the lateral faces), a
        // single-profile fallback has exactly one (#764).
        #expect(shape.subShapes(ofType: .face).count > 1)

        let polylines = shape.allEdgePolylines()
        // Should return polylines for most/all edges
        #expect(polylines.count > 0)
        // At minimum the top and bottom rectangle edges should be present
        #expect(polylines.count >= 4)
        for poly in polylines {
            #expect(poly.count >= 2)
        }
    }

    @Test("Extruded shape returns all edge polylines")
    func extrudedEdgePolylines() {
        // Extrude a rectangle profile
        let wire = Wire.rectangle(width: 10, height: 5)!
        let extruded = Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 15)
        #expect(extruded != nil)
        guard let shape = extruded else { return }

        let edgeCount = shape.edges().count
        let polylines = shape.allEdgePolylines()
        // Every edge should produce a polyline
        #expect(polylines.count == edgeCount)
    }

    @Test("Cylinder edge polylines include circular edges")
    func cylinderEdgePolylines() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let polylines = cyl.allEdgePolylines()
        // Cylinder has 3 edges: top circle, bottom circle, seam
        #expect(polylines.count >= 2)
        // Circular edges should have many points
        let longPoly = polylines.max(by: { $0.count < $1.count })!
        #expect(longPoly.count >= 10)
    }

    @Test("Single edge polyline by index")
    func singleEdgePolyline() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let poly = box.edgePolyline(at: 0)
        #expect(poly != nil)
        #expect(poly!.count >= 2)
        // Out of bounds returns nil
        let bad = box.edgePolyline(at: 999)
        #expect(bad == nil)
    }
}
