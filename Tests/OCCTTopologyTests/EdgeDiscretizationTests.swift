import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Edge Discretization Tests")
struct EdgeDiscretizationTests {

    @Test("Edge polyline from box")
    func edgePolylineFromBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Box has edges (OCCT may count shared edges per face)
        #expect(box.edgeCount > 0)

        // Get polyline for first edge
        let polyline = box.edgePolyline(at: 0, deflection: 0.1)
        #expect(polyline != nil)
        if let pts = polyline {
            #expect(pts.count >= 2)  // At least start and end
        }
    }

    @Test("Edge polyline from curved shape")
    func edgePolylineFromCylinder() {
        let cylinder = Shape.cylinder(radius: 10, height: 20)!

        // Cylinder has curved edges
        let polyline = cylinder.edgePolyline(at: 0, deflection: 0.1)
        #expect(polyline != nil)
        if let pts = polyline {
            // Curved edges should have many points
            #expect(pts.count > 2)
        }
    }

    @Test("All edge polylines")
    func allEdgePolylines() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let polylines = box.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == box.edgeCount)
    }

    @Test("Edge polyline invalid index")
    func edgePolylineInvalidIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Box has 12 edges, index 100 should fail
        let polyline = box.edgePolyline(at: 100, deflection: 0.1)
        #expect(polyline == nil)
    }

    // MARK: - Bulk edge discretisation (#275)

    /// The bulk path must agree point-for-point with the per-index accessor it replaced,
    /// same edge ordering, same discretisation, same skip behaviour.
    @Test("Bulk allEdgePolylines matches the per-index accessor exactly")
    func bulkEdgePolylinesMatchPerIndex() {
        // A box (planar edges) and a cylinder (curved edges + the seam) cover both the
        // BRepAdaptor_Curve path and multi-point discretisation.
        for shape in [
            Shape.box(width: 10, height: 10, depth: 10)!,
            Shape.cylinder(radius: 5, height: 20)!,
        ] {
            let bulk = shape.allEdgePolylines(deflection: 0.1)

            var perIndex: [[SIMD3<Double>]] = []
            for i in 0..<shape.edgeCount {
                if let poly = shape.edgePolyline(at: i, deflection: 0.1, maxPoints: 1000) {
                    perIndex.append(poly)
                }
            }

            #expect(bulk.count == perIndex.count)
            for (b, p) in zip(bulk, perIndex) {
                #expect(b.count == p.count)
                for (bp, pp) in zip(b, p) {
                    #expect(bp.x == pp.x)
                    #expect(bp.y == pp.y)
                    #expect(bp.z == pp.z)
                }
            }
        }
    }

    /// Regression guard for #275: `allEdgePolylines` must scale ~linearly in edge count.
    ///
    /// The old implementation rebuilt the full `TopTools_IndexedMapOfShape` inside every
    /// per-index call, so total work grew quadratically (measured on the issue: 800 edges
    /// 0.11 s → 3,136 edges 1.29 s → 12,033 edges 20.3 s). We compare per-edge cost between
    /// a small and a ~10x larger shape: linear keeps the ratio ~flat, quadratic makes it grow
    /// with the edge count. The bound is deliberately loose (8x) so this asserts the
    /// complexity class, not wall-clock, it should not go red on a slow or busy machine.
    @Test("allEdgePolylines scales linearly, not quadratically, in edge count")
    func allEdgePolylinesScalesLinearly() {
        func perEdgeCost(gridSide: Int) -> (cost: Double, edges: Int) {
            // A compound of many small boxes: edge count scales with the box count, and
            // every edge is independent, so total work should be linear in edges.
            var boxes: [Shape] = []
            for i in 0..<gridSide {
                for j in 0..<gridSide {
                    boxes.append(
                        Shape.box(width: 1, height: 1, depth: 1)!
                            .translated(by: SIMD3(Double(i) * 2, Double(j) * 2, 0))!)
                }
            }
            let compound = Shape.compound(boxes)!
            let edges = compound.edgeCount

            let start = Date()
            let polylines = compound.allEdgePolylines(deflection: 0.1)
            let elapsed = Date().timeIntervalSince(start)

            #expect(polylines.count == edges)
            return (elapsed / Double(edges), edges)
        }

        let small = perEdgeCost(gridSide: 3)  // 9 boxes   → 108 edges
        let large = perEdgeCost(gridSide: 10)  // 100 boxes → 1200 edges

        // Sanity: the large case really is ~10x the edges, or the guard proves nothing.
        #expect(large.edges > small.edges * 5)

        // Linear → per-edge cost stays roughly constant. Quadratic → it grows ~11x here.
        #expect(
            large.cost < small.cost * 8,
            "per-edge cost grew \(large.cost / small.cost)x from \(small.edges) to \(large.edges) edges, allEdgePolylines looks quadratic again (#275)"
        )
    }

    /// `allEdgePolylinesIndexed` must carry ORIGINAL edge indices across skips: a sphere
    /// has degenerate pole edges the discretizer skips, so the dense variant's positions
    /// drift out of the `edgePolyline(at:)` index space exactly there. The indexed variant
    /// exists for consumers (wireframe pick identity) that can't tolerate that drift.
    @Test("allEdgePolylinesIndexed preserves the edgePolyline(at:) index space across skips")
    func indexedEdgePolylinesSurviveSkips() {
        let sphere = Shape.sphere(radius: 5)!
        let indexed = sphere.allEdgePolylinesIndexed(deflection: 0.1)

        // Something must actually be skipped for this fixture to prove anything.
        #expect(
            indexed.count < sphere.edgeCount,
            "sphere fixture no longer has a skipped (degenerate) edge, pick a new fixture")

        // Every returned pair must match the per-index accessor at that exact index…
        for (edgeIndex, points) in indexed {
            let single = sphere.edgePolyline(at: edgeIndex, deflection: 0.1, maxPoints: 1000)
            #expect(single != nil)
            #expect(single?.count == points.count)
            if let single {
                for (a, b) in zip(single, points) {
                    #expect(a.x == b.x)
                    #expect(a.y == b.y)
                    #expect(a.z == b.z)
                }
            }
        }

        // …and the skipped indices must be exactly those the per-index accessor also rejects.
        let returned = Set(indexed.map(\.edgeIndex))
        for i in 0..<sphere.edgeCount where !returned.contains(i) {
            #expect(
                sphere.edgePolyline(at: i, deflection: 0.1, maxPoints: 1000) == nil,
                "edge \(i) was skipped by the bulk pass but discretizes fine per-index")
        }

        // The dense variant is the indexed one minus the indices.
        let dense = sphere.allEdgePolylines(deflection: 0.1)
        #expect(dense.count == indexed.count)
        for (d, ip) in zip(dense, indexed) {
            #expect(d.count == ip.points.count)
        }
    }
}
