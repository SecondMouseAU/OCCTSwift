import Testing

@testable import OCCTSwift

// MARK: - Edge Polyline Tests (Issue #29)

@Suite("Edge Polylines, Lofted and Extruded Shapes")
struct EdgePolylineTests {
    @Test("Box edge polylines returns all 12 edges")
    func boxEdgePolylines() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let polylines = box.allEdgePolylines()
        #expect(polylines.count == 12)
        for poly in polylines {
            #expect(poly.count >= 2)
        }
    }

    @Test("Lofted solid returns edge polylines")
    func loftedEdgePolylines() throws {
        // Loft between two rectangles of different sizes
        let bottom = try #require(Wire.rectangle(width: 10, height: 10))
        let top = try #require(Wire.rectangle(width: 5, height: 5))
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
    func extrudedEdgePolylines() throws {
        // Extrude a rectangle profile
        let wire = try #require(Wire.rectangle(width: 10, height: 5))
        let extruded = Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 15)
        #expect(extruded != nil)
        guard let shape = extruded else { return }

        let edgeCount = shape.edges().count
        let polylines = shape.allEdgePolylines()
        // Every edge should produce a polyline
        #expect(polylines.count == edgeCount)
    }

    // #3332: the old assertions were `count >= 2` and `longest >= 10` points. A radius-5, 10 high
    // cylinder has exactly three edges (top circle, bottom circle, seam). Measured: the circles
    // come back as 64-point closed polylines and the seam as a 2-point segment.
    @Test("Cylinder edge polylines include circular edges")
    func cylinderEdgePolylines() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let polylines = cyl.allEdgePolylines()
        #expect(polylines.count == 3)
        #expect(polylines.map { $0.count }.sorted() == [2, 64, 64])

        var circleHeights: [Double] = []
        for poly in polylines where poly.count > 2 {
            // Closed: the last point is the first.
            let first = try #require(poly.first)
            let last = try #require(poly.last)
            #expect(abs(first.x - last.x) < 1e-9 && abs(first.y - last.y) < 1e-9)
            #expect(abs(first.z - last.z) < 1e-9)
            // On the cylinder wall, at one height.
            for p in poly {
                #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 5) < 1e-9)
                #expect(abs(p.z - first.z) < 1e-9)
            }
            circleHeights.append(first.z)
        }
        #expect(circleHeights.sorted().count == 2)
        if circleHeights.count == 2 {
            let heights = circleHeights.sorted()
            #expect(abs(heights[0] - 0) < 1e-9)
            #expect(abs(heights[1] - 10) < 1e-9)
        }

        // The seam runs the full height at the wall.
        let seam = try #require(polylines.first { $0.count == 2 })
        #expect(abs(abs(seam[0].z - seam[1].z) - 10) < 1e-9)
        for p in seam {
            #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 5) < 1e-9)
        }
    }

    @Test("Single edge polyline by index")
    func singleEdgePolyline() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let poly = box.edgePolyline(at: 0)
        #expect(poly != nil)
        #expect(try #require(poly).count >= 2)
        // Out of bounds returns nil
        let bad = box.edgePolyline(at: 999)
        #expect(bad == nil)
    }
}
