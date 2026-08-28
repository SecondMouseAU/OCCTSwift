import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_ToroidalSurface Properties")
struct GeomTorus3DTests {
    @Test func torusRadii() {
        if let t = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2)
        {
            #expect(abs(t.torusProperties.majorRadius - 10) < 1e-6)
            #expect(abs(t.torusProperties.minorRadius - 2) < 1e-6)
        }
    }

    @Test func torusSetRadii() {
        if let t = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2)
        {
            #expect(t.torusProperties.setMajorRadius(15))
            #expect(abs(t.torusProperties.majorRadius - 15) < 1e-6)
            #expect(t.torusProperties.setMinorRadius(3))
            #expect(abs(t.torusProperties.minorRadius - 3) < 1e-6)
        }
    }

    @Test func torusArea() {
        if let t = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2)
        {
            let area = t.torusProperties.area
            #expect(abs(area - 4 * Double.pi * Double.pi * 10 * 2) < 1.0)
        }
    }

    @Test func torusVolume() {
        if let t = Surface.torus(
            origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2)
        {
            let vol = t.torusProperties.volume
            #expect(abs(vol - 2 * Double.pi * Double.pi * 10 * 4) < 1.0)
        }
    }
}
