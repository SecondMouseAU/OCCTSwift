import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GeomConvert_SurfToAnaSurf on the pinned kernel
// (Scripts/repro/766-curve-final-sampling/transcript.txt): the BSpline of a trimmed plane is
// recognized as a Geom_Plane with gap 0, and IsCanonical is true for the plane, false for the
// BSpline.
@Suite("GeomConvert_SurfToAnaSurf")
struct SurfToAnaSurfTests {
    @Test("recognize plane from BSpline")
    func recognizePlane() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bsp = trimmed.toBSpline()
        else {
            Issue.record("plane, trim or BSpline conversion was nil")
            return
        }
        guard let result = bsp.toAnalyticalWithGap(tolerance: 1e-4) else {
            Issue.record("a planar BSpline was not recognized")
            return
        }
        #expect(result.surface.surfaceKind == .plane)
        #expect(result.gap < 1e-12)
    }

    @Test("is canonical")
    func isCanonical() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bsp = trimmed.toBSpline()
        else {
            Issue.record("plane, trim or BSpline conversion was nil")
            return
        }
        #expect(plane.isCanonical)
        #expect(!bsp.isCanonical)
    }
}
