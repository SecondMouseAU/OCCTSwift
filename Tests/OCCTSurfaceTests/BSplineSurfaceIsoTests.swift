import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineSurface Iso Curves")
struct BSplineSurfaceIsoTests {
    @Test("UIso returns curve")
    func uIso() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let iso = bs.bsplineUIso(u: uMid)
            #expect(iso != nil)
        }
    }

    @Test("VIso returns curve")
    func vIso() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        if let bs = sphere?.toBSpline() {
            let bounds = bs.bsplineBounds
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let iso = bs.bsplineVIso(v: vMid)
            #expect(iso != nil)
        }
    }
}
