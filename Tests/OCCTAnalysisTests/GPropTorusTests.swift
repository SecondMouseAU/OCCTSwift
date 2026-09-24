import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1791, #1792: the tolerance here was 1.0, against an area of 1184 and a volume of 1777, so an
// integration range cut short by a milliradian (0.19 off the area) still passed. GProp integrates a
// full torus exactly: both values equal the closed form to the last bit, measured in
// Scripts/repro/766-gprop-torus/transcript.txt, so the tolerance is now relative and tight.
@Suite("GProp Torus Tests")
struct GPropTorusTests {

    @Test func torusSurfaceArea() {
        let R = 10.0  // major
        let r = 3.0  // minor
        let area = GeometryProperties.torusSurfaceArea(majorRadius: R, minorRadius: r)
        let expected = 4 * Double.pi * Double.pi * R * r
        #expect(abs(area - expected) < 1e-9 * expected)
    }

    @Test func torusVolume() {
        let R = 10.0
        let r = 3.0
        let vol = GeometryProperties.torusVolume(majorRadius: R, minorRadius: r)
        let expected = 2 * Double.pi * Double.pi * R * r * r
        #expect(abs(vol - expected) < 1e-9 * expected)
    }
}
