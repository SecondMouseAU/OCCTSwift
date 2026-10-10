import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: the two circle tests skipped their assertions on a nil dimension (`if let`), and the
// non-circular test's `!dim.isValid || dim.value >= 0` held for every dimension whatever it
// measured. PrsDim_RadiusDimension, measured in
// Scripts/repro/766-drawing-radial-radius/transcript.txt, gives radius 7 / 5 on the circle wires,
// and on the box constructs a dimension that reports itself invalid with value 0.
@Suite("Radius Dimension")
struct RadiusDimensionTests {

    @Test("Radius of circle wire")
    func circleRadius() {
        guard let wireShape = Wire.circle(radius: 7).flatMap({ Shape.fromWire($0) }),
            let dim = RadiusDimension(shape: wireShape)
        else {
            Issue.record("RadiusDimension(shape:) returned nil for a circle")
            return
        }
        #expect(abs(dim.value - 7.0) < 1e-4, "Radius should be 7, got \(dim.value)")
    }

    @Test("Radius geometry has circle center")
    func radiusGeometry() {
        guard let wireShape = Wire.circle(radius: 5).flatMap({ Shape.fromWire($0) }),
            let dim = RadiusDimension(shape: wireShape),
            let g = dim.geometry
        else {
            Issue.record("RadiusDimension or its geometry was nil for a circle")
            return
        }
        #expect(abs(g.circleRadius - 5) < 1e-9, "circleRadius \(g.circleRadius)")
        #expect(simd_length(g.centerPoint) < 1e-9, "centre \(g.centerPoint)")
        #expect(g.isValid)
    }

    @Test("Nil for non-circular shape")
    func nonCircularFails() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box fixture failed")
            return
        }
        // Either refusal is acceptable; what must not happen is a valid radius for a box. The
        // pinned kernel constructs the dimension and reports it invalid.
        if let dim = RadiusDimension(shape: box) {
            #expect(!dim.isValid)
        }
    }
}
