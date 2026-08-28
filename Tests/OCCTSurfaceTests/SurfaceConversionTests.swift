import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Conversion")
struct SurfaceConversionTests {
    @Test("Sphere to BSpline conversion")
    func sphereToBSpline() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let bsp = sphere.toBSpline()
        #expect(bsp != nil)
        if let bsp = bsp {
            #expect(bsp.uDegree > 0)
            #expect(bsp.vDegree > 0)
            // Both share same parametrization; evaluate at domain midpoint
            let dom = sphere.domain
            let uMid = (dom.uMin + dom.uMax) / 2
            let vMid = (dom.vMin + dom.vMax) / 2
            let pOrig = sphere.point(atU: uMid, v: vMid)
            let pBsp = bsp.point(atU: uMid, v: vMid)
            let diff = simd_length(pOrig - pBsp)
            #expect(diff < 0.01)
            // Both should be on sphere surface
            #expect(abs(simd_length(pOrig) - 5.0) < 1e-6)
            #expect(abs(simd_length(pBsp) - 5.0) < 0.01)
        }
    }

    @Test("Approximate surface")
    func approximateSurface() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let approx = sphere.approximated(tolerance: 0.001)
        #expect(approx != nil)
    }

    @Test("U-iso curve from sphere")
    func uIsoCurve() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let iso = sphere.uIso(at: 0)
        #expect(iso != nil)
        if let iso = iso {
            // U-iso at u=0 is a meridian (half-circle)
            let p = iso.startPoint
            let dist = simd_length(p)
            #expect(abs(dist - 5.0) < 1e-6)
        }
    }

    @Test("V-iso curve from sphere")
    func vIsoCurve() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let iso = sphere.vIso(at: 0)
        #expect(iso != nil)
        if let iso = iso {
            // V-iso at v=0 is the equator (circle)
            #expect(iso.isClosed == true)
        }
    }
}
