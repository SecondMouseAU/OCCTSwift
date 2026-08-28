import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GProp Torus Tests")
struct GPropTorusTests {

    @Test func torusSurfaceArea() {
        let R = 10.0  // major
        let r = 3.0  // minor
        let area = GeometryProperties.torusSurfaceArea(majorRadius: R, minorRadius: r)
        let expected = 4 * Double.pi * Double.pi * R * r
        #expect(abs(area - expected) < 1.0)
    }

    @Test func torusVolume() {
        let R = 10.0
        let r = 3.0
        let vol = GeometryProperties.torusVolume(majorRadius: R, minorRadius: r)
        let expected = 2 * Double.pi * Double.pi * R * r * r
        #expect(abs(vol - expected) < 1.0)
    }
}
