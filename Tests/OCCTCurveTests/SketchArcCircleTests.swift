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
        #expect(pts.count > 50)  // 8 * 2π ≈ 50
        // All points lie on radius 5.
        for p in pts {
            let r = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(r - 5.0) < 1e-9)
        }
    }

    @Test("Arc tessellation stays within bounds")
    func arcTessellation() {
        let arc = SketchElement.CurveKind.arc(
            center: SIMD2(0, 0), radius: 2,
            startAngle: 0, endAngle: .pi / 2)
        let pts = arc.tessellate2D(segmentsPerRadian: 16)
        // Start at (2, 0), end at (0, 2).
        #expect(abs(pts.first!.x - 2) < 1e-9)
        #expect(abs(pts.last!.y - 2) < 1e-9)
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
        let wire = sketch.buildProfile(in: ctx, graph: graph)
        #expect(wire != nil)
    }
}
