import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GProp Cylinder/Cone Tests")
struct GPropCylConeTests {

    @Test func cylinderSurfaceArea() {
        let area = GeometryProperties.cylinderSurfaceArea(radius: 5, height: 10)
        let expected = 2 * Double.pi * 5 * 10
        #expect(abs(area - expected) < 0.1)
    }

    @Test func cylinderVolume() {
        let vol = GeometryProperties.cylinderVolume(radius: 5, height: 10)
        let expected = Double.pi * 25 * 10
        #expect(abs(vol - expected) < 1.0)
    }

    @Test func coneSurfaceArea() {
        let area = GeometryProperties.coneSurfaceArea(semiAngle: .pi / 6, refRadius: 5, height: 10)
        #expect(area > 0)
    }

    @Test func coneVolume() {
        let vol = GeometryProperties.coneVolume(semiAngle: .pi / 6, refRadius: 5, height: 10)
        #expect(vol > 0)
    }
}
