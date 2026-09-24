import Testing
import simd

@testable import OCCTSwift

@Suite("BSpline Surface RemoveVKnot v0.120.0")
struct BSplineSurfaceRemoveVKnotTests {

    // The fixture (a 4x4 point-grid fit, z = sin(u*0.5) * cos(v*0.5)) lives in
    // `SurfaceTestFixtures.swift` as `makeSinCosGridBSplineSurface()`; see #1254.
    func makeBSplineSurface() -> Surface? {
        makeSinCosGridBSplineSurface()
    }

    @Test func removeVKnot() {
        // #766: was `let _ = ...` then `#expect(true)`, which nothing could fail. A boundary knot
        // cannot be removed (Geom_BSplineSurface::RemoveVKnot throws "invalid Index", the bridge
        // says false); an inserted simple interior knot can, at a generous tolerance, leaving the
        // knot count where it started. Kernel values from Scripts/repro/766-bspline-manipulation/.
        let fixture = makeBSplineSurface()
        #expect(fixture != nil)
        if let s = fixture {
            #expect(!s.bsplineRemoveVKnot(index: 1, mult: 0, tolerance: 1.0))
            let before = s.bsplineVKnots().count
            #expect(s.bsplineInsertVKnots([0.5], multiplicities: [1]))
            #expect(s.bsplineVKnots().count == before + 1)
            #expect(s.bsplineRemoveVKnot(index: 2, mult: 0, tolerance: 1.0))
            #expect(s.bsplineVKnots().count == before)
        }
    }
}
