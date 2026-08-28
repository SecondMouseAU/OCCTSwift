import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Diameter Dimension")
struct DiameterDimensionTests {

    @Test("Diameter of circle is twice radius")
    func circleDiameter() {
        let wire = Wire.circle(radius: 8)!
        let wireShape = Shape.fromWire(wire)!
        let dim = DiameterDimension(shape: wireShape)
        if let dim = dim {
            #expect(abs(dim.value - 16.0) < 1e-4, "Diameter should be 16, got \(dim.value)")
        }
    }

    @Test("Diameter geometry has circle info")
    func diameterGeometry() {
        let wire = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(wire)!
        let dim = DiameterDimension(shape: wireShape)
        if let dim = dim, let g = dim.geometry {
            #expect(g.circleRadius > 0)
            // First and second points should be diametrically opposite
            let dist = simd_distance(g.firstPoint, g.secondPoint)
            #expect(
                abs(dist - 10.0) < 1e-3,
                "Diameter endpoints should be 10 apart, got \(dist)")
        }
    }

    @Test("Custom value on diameter")
    func customDiameter() {
        let wire = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(wire)!
        guard let dim = DiameterDimension(shape: wireShape) else { return }
        dim.setCustomValue(99.0)
        #expect(abs(dim.value - 99.0) < 1e-6)
    }
}
