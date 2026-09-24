import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.143 D2: Arc/circle in Sketch.buildProfile

@Suite("v0.143 Sketch arcs and circles")
struct SketchArcCircleTests {
    @Test("Circle tessellation produces a closed polygon of N points")
    func circleTessellation() {
        let circle = SketchElement.CurveKind.circle(center: SIMD2(0, 0), radius: 5)
        let pts = circle.tessellate2D(segmentsPerRadian: 8)
        // Int(8 * 2pi) = 50 segments, so 51 points with the last repeating the first.
        #expect(pts.count == 51)
        // All points lie on radius 5.
        for p in pts {
            let r = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(r - 5.0) < 1e-9)
        }
        if let first = pts.first, let last = pts.last {
            #expect(simd_distance(first, SIMD2(5, 0)) < 1e-9)
            #expect(simd_distance(last, first) < 1e-9)
        }
    }

    @Test("Arc tessellation stays within bounds")
    func arcTessellation() {
        let arc = SketchElement.CurveKind.arc(
            center: SIMD2(0, 0), radius: 2,
            startAngle: 0, endAngle: .pi / 2)
        let pts = arc.tessellate2D(segmentsPerRadian: 16)
        // Int(16 * pi/2) = 25 segments, 26 points, from (2, 0) to (0, 2).
        #expect(pts.count == 26)
        guard let first = pts.first, let last = pts.last else {
            Issue.record("arc tessellation was empty")
            return
        }
        #expect(simd_distance(first, SIMD2(2, 0)) < 1e-9)
        #expect(simd_distance(last, SIMD2(0, 2)) < 1e-9)
        for p in pts {
            #expect(abs(simd_length(p) - 2) < 1e-9)
        }
    }

    @Test("buildProfile with arc yields a wire")
    func buildProfileWithArc() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let ctx = ConstructionContext()
        let planeID = ctx.add(.absolute(origin: .zero, normal: SIMD3(0, 0, 1)))
        var sketch = Sketch(hostPlane: planeID)
        // A closed D-shape: straight line + semicircle arc
        sketch.add(SketchElement(curve: .line(from: SIMD2(0, 0), to: SIMD2(10, 0))))
        sketch.add(
            SketchElement(
                curve: .arc(
                    center: SIMD2(5, 0), radius: 5,
                    startAngle: 0, endAngle: .pi)))
        guard let wire = sketch.buildProfile(in: ctx, graph: graph) else {
            Issue.record("buildProfile returned nil")
            return
        }
        // Pinned to BRepBuilderAPI_MakePolygon on the same 52 points, closed
        // (Scripts/repro/766-curve-final-sampling/transcript.txt): the line, 50 arc chords, and
        // the closing edge collapse to 51 edges, 10 + 50 chords of the r=5 semicircle long.
        #expect(wire.orderedEdgeCount == 51)
        if let length = wire.length {
            #expect(abs(length - 25.7053795391) < 1e-9)
        } else {
            Issue.record("wire length was nil")
        }
    }
}
