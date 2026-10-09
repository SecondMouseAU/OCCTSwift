import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_RectangularTrimmedSurface Tests")
struct RectangularTrimmedSurfaceTests {

    // #766: each asserted only non-nil; a trim that kept the wrong range passed. Bounds are
    // Geom_RectangularTrimmedSurface's own (Scripts/repro/766-projection-trim-revolution-section/); the untrimmed direction keeps the
    // plane's infinite range (+-2e100).
    @Test func trimPlane() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        let trimmed = Surface.rectangularTrimmed(
            basis: plane,
            u1: -5, u2: 5, v1: -3, v2: 3)
        #expect(trimmed != nil)
        if let d = trimmed?.domain {
            #expect(d.uMin == -5 && d.uMax == 5 && d.vMin == -3 && d.vMax == 3)
        }
    }

    @Test func trimInU() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        let trimmed = Surface.trimmedInU(basis: plane, param1: -2, param2: 2)
        #expect(trimmed != nil)
        if let d = trimmed?.domain {
            #expect(d.uMin == -2 && d.uMax == 2)
            #expect(d.vMin < -1e99 && d.vMax > 1e99)
        }
    }

    @Test func trimInV() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        let trimmed = Surface.trimmedInV(basis: plane, param1: -3, param2: 3)
        #expect(trimmed != nil)
        if let d = trimmed?.domain {
            #expect(d.vMin == -3 && d.vMax == 3)
            #expect(d.uMin < -1e99 && d.uMax > 1e99)
        }
    }
}
