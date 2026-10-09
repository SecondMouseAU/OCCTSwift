import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: both tests used to assert only `result != nil` (and the sphere test returned silently
// if its line failed to build), so a projection landing anywhere, with any number of edges,
// passed. They now pin what BRepProj_Projection produces for the same inputs, measured in
// Scripts/repro/766-drawing-thread-cylproj-diameter/transcript.txt.
@Suite("Cylindrical Projection")
struct CylindricalProjectionTests {
    private func expectBox(
        _ bb: (min: SIMD3<Double>, max: SIMD3<Double>),
        min: SIMD3<Double>, max: SIMD3<Double>
    ) {
        #expect(simd_length(bb.min - min) < 1e-6, "bbox min \(bb.min), expected \(min)")
        #expect(simd_length(bb.max - max) < 1e-6, "bbox max \(bb.max), expected \(max)")
    }

    @Test("Project wire onto box")
    func projectWireOntoBox() {
        // Create a circle wire above a box, project downward onto the box. Shape.box is centred
        // on the origin (x, y in [-5, 5], z in [-2.5, 2.5]), so the circle centred at (5, 5)
        // straddles the box's corner: the quarter inside the footprint lands on both the top and
        // the bottom face, four edges spanning x, y in [2, 5].
        guard let circle = Wire.circle(radius: 3),
            let circleShape = Shape.fromWire(circle)?.translated(by: SIMD3(5, 5, 20)),
            let box = Shape.box(width: 10, height: 10, depth: 5)
        else {
            Issue.record("setup nil")
            return
        }
        guard let result = Shape.projectWire(circleShape, onto: box, direction: SIMD3(0, 0, -1))
        else {
            Issue.record("projectWire returned nil")
            return
        }
        #expect(result.edges().count == 4)
        guard let bb = result.boundingBox else {
            Issue.record("projection has no bounding box")
            return
        }
        expectBox(bb, min: SIMD3(1.9999999, 1.9999999, -2.5000001), max: SIMD3(5.0000001, 5.0000001, 2.5000001))
    }

    @Test("Project edge onto sphere")
    func projectEdgeOntoSphere() {
        // Line above sphere, project downward onto sphere surface: it lands on the upper and
        // the lower hemisphere, x in [-3, 3], z reaching +/-10 at x = 0.
        guard let line = Wire.line(from: SIMD3(-3, 0, 8), to: SIMD3(3, 0, 8)),
            let lineShape = Shape.fromWire(line),
            let sphere = Shape.sphere(radius: 10)
        else {
            Issue.record("setup nil")
            return
        }
        guard let result = Shape.projectWire(lineShape, onto: sphere, direction: SIMD3(0, 0, -1))
        else {
            Issue.record("projectWire returned nil")
            return
        }
        #expect(result.edges().count == 4)
        guard let bb = result.boundingBox else {
            Issue.record("projection has no bounding box")
            return
        }
        expectBox(bb, min: SIMD3(-3.0000001, -1.00000001e-7, -10.0000001), max: SIMD3(3.0000001, 1.00000001e-7, 10.0000001))
    }
}
