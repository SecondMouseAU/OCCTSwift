import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts, positions and distances are BRepMAT2d_BisectingLocus's on the same face; see
// Scripts/repro/766-medial-axis/transcript.txt. The suite was disabled for a segfault that only
// the circle fixture in MedialAxisVariousShapesTests reproduces.
@Suite("Medial Axis, Rectangle")
struct MedialAxisRectangleTests {

    @Test("Rectangle produces non-nil medial axis")
    func rectangleComputesSuccessfully() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        let ma = MedialAxis(of: face)
        #expect(ma != nil)
    }

    @Test("Rectangle has correct arc and node counts")
    func rectangleGraphCounts() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        // Four corner bisectors meeting the central segment between (-3, 0) and (3, 0).
        #expect(ma.arcCount == 5)
        #expect(ma.nodeCount == 6)
        #expect(ma.basicElementCount == 4)
    }

    @Test("Rectangle min thickness equals half the short side")
    func rectangleMinThickness() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        // Min thickness = inscribed circle radius at narrowest point = half of short side = 2.0
        let minT = ma.minThickness
        #expect(minT > 0)
        #expect(abs(minT - 2.0) < 0.1, "Expected min thickness ~2.0 for 10x4 rect, got \(minT)")
    }

    @Test("Rectangle nodes have valid positions and distances")
    func rectangleNodes() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        let nodes = ma.nodes
        #expect(nodes.count == ma.nodeCount)

        for node in nodes {
            // Node positions should be inside the rectangle
            #expect(
                node.distance > 0 || node.isOnBoundary,
                "Node \(node.index) has invalid distance \(node.distance)")
        }
    }

    @Test("Rectangle arcs have valid node references")
    func rectangleArcs() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        let arcs = ma.arcs
        #expect(arcs.count == ma.arcCount)

        for arc in arcs {
            // Node indices should be within valid range
            #expect(arc.firstNodeIndex >= 1 && arc.firstNodeIndex <= Int32(ma.nodeCount))
            #expect(arc.secondNodeIndex >= 1 && arc.secondNodeIndex <= Int32(ma.nodeCount))
        }
    }

    @Test("Rectangle arc drawing produces polylines")
    func rectangleDrawArc() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        guard ma.arcCount > 0 else {
            Issue.record("No arcs in medial axis")
            return
        }
        let points = ma.drawArc(at: 1, maxPoints: 20)
        #expect(points.count == 20, "Expected 20 sample points, got \(points.count)")
        // Points should be finite
        for pt in points {
            #expect(pt.x.isFinite && pt.y.isFinite, "Non-finite point in arc drawing")
        }
    }

    @Test("Rectangle draw all produces one polyline per arc")
    func rectangleDrawAll() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        let polylines = ma.drawAll(maxPointsPerArc: 16)
        #expect(polylines.count == ma.arcCount)
        for polyline in polylines {
            #expect(polyline.count >= 2)
        }
    }

    @Test("Rectangle distance on arc interpolates between endpoints")
    func rectangleDistanceOnArc() {
        let wire = Wire.rectangle(width: 10, height: 4)!
        let face = Shape.face(from: wire)!
        guard let ma = MedialAxis(of: face) else {
            Issue.record("Failed to compute medial axis")
            return
        }
        guard ma.arcCount > 0 else { return }
        // Find an arc where both endpoints have positive distance
        // (some arcs may touch the boundary where distance = 0)
        var foundArc = false
        for i in 1...ma.arcCount {
            let d0 = ma.distanceToBoundary(arcIndex: i, parameter: 0)
            let d1 = ma.distanceToBoundary(arcIndex: i, parameter: 1)
            if d0 > 0.01 && d1 > 0.01 {
                let dMid = ma.distanceToBoundary(arcIndex: i, parameter: 0.5)
                #expect(dMid > 0)
                // Midpoint should be between endpoints (linear interpolation)
                let expected = (d0 + d1) / 2.0
                #expect(abs(dMid - expected) < 1e-10)
                foundArc = true
                break
            }
        }
        // Arc 5, the central segment, is 2 from the boundary along its whole length.
        #expect(foundArc, "no arc has both endpoints off the boundary")
        // At minimum, verify the function doesn't crash
        let d = ma.distanceToBoundary(arcIndex: 1, parameter: 0.5)
        #expect(d >= 0, "Distance should be non-negative")
        if !foundArc {
            // All arcs touch the boundary, still valid, just verify non-negative
            #expect(d >= 0)
        }
    }
}
