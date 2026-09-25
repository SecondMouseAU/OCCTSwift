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
        // #766: was non-nil only. GeomConvert_ApproxSurface at 1e-3 / degree 8 gives degree
        // 8 x 8 with 15 x 9 poles on this sphere (Scripts/repro/766-surface-conversion/).
        if let approx {
            #expect(approx.uDegree == 8 && approx.vDegree == 8)
            #expect(approx.uPoleCount == 15 && approx.vPoleCount == 9)
        }
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
            // #766: any point at radius 5 passed. The meridian at u = 0 starts at the south pole
            // and passes (5, 0, 0) at v = 0.
            #expect(simd_length(p - SIMD3(0, 0, -5)) < 1e-12)
            #expect(simd_length(iso.point(at: 0) - SIMD3(5, 0, 0)) < 1e-12)
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
            // #766: any closed curve passed; the equator passes (0, 5, 0) at u = pi/2.
            #expect(simd_length(iso.point(at: .pi / 2) - SIMD3(0, 5, 0)) < 1e-12)
        }
    }
}
