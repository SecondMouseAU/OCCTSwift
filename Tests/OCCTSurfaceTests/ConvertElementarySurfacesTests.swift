import Testing
import simd

@testable import OCCTSwift

@Suite("Convert Elementary Surfaces Tests")
struct ConvertElementarySurfacesTests {

    // #766: each test asserted only `s != nil`, so a patch built from the wrong radius or cone
    // passed. Each now also pins the domain and the point at 30% / 60% of it, which is what the
    // same Convert_*ToBSplineSurface rebuilt into a Geom_BSplineSurface gives, see
    // Scripts/repro/766-convert-check-evolved-revol/.
    private func pointAt30x60(_ s: Surface) -> SIMD3<Double> {
        let d = s.domain
        return s.point(atU: d.uMin + 0.3 * (d.uMax - d.uMin), v: d.vMin + 0.6 * (d.vMax - d.vMin))
    }

    @Test func cylinderPatch() {
        let s = Surface.fromCylinder(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5,
            u1: 0, u2: .pi, v1: 0, v2: 10)
        #expect(s != nil)
        if let s {
            #expect(s.domain.uMax == .pi && s.domain.vMax == 10)
            #expect(simd_length(pointAt30x60(s) - SIMD3(2.9055429055745949, 4.0691301802553754, 6)) < 1e-12)
        }
    }

    @Test func conePatch() {
        let s = Surface.fromCone(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 6, refRadius: 5,
            u1: 0, u2: .pi, v1: 0, v2: 10)
        #expect(s != nil)
        if let s {
            #expect(s.domain.uMax == .pi && s.domain.vMax == 10)
            #expect(simd_length(pointAt30x60(s) - SIMD3(4.6488686489193523, 6.5106082884085996, 5.196152422706632)) < 1e-12)
        }
    }

    @Test func fullTorus() {
        let s = Surface.fromTorus(
            origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            majorRadius: 20, minorRadius: 5)
        #expect(s != nil)
        if let s {
            #expect(s.domain.uMax == 2 * .pi && s.domain.vMax == 2 * .pi)
            #expect(simd_length(pointAt30x60(s) - SIMD3(-5.3865777080062784, 15.141849190972033, -3.0929478706587101)) < 1e-12)
        }
    }
}
