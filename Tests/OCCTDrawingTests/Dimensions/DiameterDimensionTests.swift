import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: all three tests used to skip their assertions when the dimension (or its geometry)
// came back nil, via `if let` or `guard ... else { return }`, so a constructor that failed
// passed them all. They now record the nil. Values are PrsDim_DiameterDimension's, measured in
// Scripts/repro/766-drawing-thread-cylproj-diameter/transcript.txt.
@Suite("Diameter Dimension")
struct DiameterDimensionTests {

    @Test("Diameter of circle is twice radius")
    func circleDiameter() {
        guard let wireShape = Wire.circle(radius: 8).flatMap({ Shape.fromWire($0) }),
            let dim = DiameterDimension(shape: wireShape)
        else {
            Issue.record("DiameterDimension(shape:) returned nil for a circle")
            return
        }
        #expect(abs(dim.value - 16.0) < 1e-4, "Diameter should be 16, got \(dim.value)")
    }

    @Test("Diameter geometry has circle info")
    func diameterGeometry() {
        guard let wireShape = Wire.circle(radius: 5).flatMap({ Shape.fromWire($0) }),
            let dim = DiameterDimension(shape: wireShape),
            let g = dim.geometry
        else {
            Issue.record("DiameterDimension or its geometry was nil for a circle")
            return
        }
        #expect(abs(g.circleRadius - 5) < 1e-9, "circleRadius \(g.circleRadius)")
        // First and second points should be diametrically opposite
        let dist = simd_distance(g.firstPoint, g.secondPoint)
        #expect(
            abs(dist - 10.0) < 1e-3,
            "Diameter endpoints should be 10 apart, got \(dist)")
    }

    @Test("Custom value on diameter")
    func customDiameter() {
        guard let wireShape = Wire.circle(radius: 5).flatMap({ Shape.fromWire($0) }),
            let dim = DiameterDimension(shape: wireShape)
        else {
            Issue.record("DiameterDimension(shape:) returned nil for a circle")
            return
        }
        dim.setCustomValue(99.0)
        #expect(abs(dim.value - 99.0) < 1e-6)
    }
}
