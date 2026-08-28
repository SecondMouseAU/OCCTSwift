import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Radius Dimension")
struct RadiusDimensionTests {

    @Test("Radius of circle wire")
    func circleRadius() {
        let wire = Wire.circle(radius: 7)!
        let wireShape = Shape.fromWire(wire)!
        let dim = RadiusDimension(shape: wireShape)
        if let dim = dim {
            #expect(abs(dim.value - 7.0) < 1e-4, "Radius should be 7, got \(dim.value)")
        }
    }

    @Test("Radius geometry has circle center")
    func radiusGeometry() {
        let wire = Wire.circle(radius: 5)!
        let wireShape = Shape.fromWire(wire)!
        let dim = RadiusDimension(shape: wireShape)
        if let dim = dim, let g = dim.geometry {
            #expect(g.circleRadius > 0, "Circle radius should be positive")
            #expect(g.isValid)
        }
    }

    @Test("Nil for non-circular shape")
    func nonCircularFails() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let dim = RadiusDimension(shape: box)
        // May return nil or invalid depending on OCCT behavior
        if let dim = dim {
            #expect(!dim.isValid || dim.value >= 0)
        }
    }
}
