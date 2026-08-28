import Testing
import simd

@testable import OCCTSwift

@Suite("Convert Elementary Surfaces Tests")
struct ConvertElementarySurfacesTests {

    @Test func cylinderPatch() {
        let s = Surface.fromCylinder(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5,
            u1: 0, u2: .pi, v1: 0, v2: 10)
        #expect(s != nil)
    }

    @Test func conePatch() {
        let s = Surface.fromCone(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 6, refRadius: 5,
            u1: 0, u2: .pi, v1: 0, v2: 10)
        #expect(s != nil)
    }

    @Test func fullTorus() {
        let s = Surface.fromTorus(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            majorRadius: 20, minorRadius: 5)
        #expect(s != nil)
    }
}
