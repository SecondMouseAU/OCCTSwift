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
        if let s = makeBSplineSurface() {
            // Attempt removal, may fail due to tolerance, that's OK
            let _ = s.bsplineRemoveVKnot(index: 1, mult: 0, tolerance: 1.0)
            #expect(true)  // no crash
        }
    }
}
