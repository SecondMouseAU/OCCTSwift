import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert_SurfToAnaSurf")
struct SurfToAnaSurfTests {
    @Test("recognize plane from BSpline")
    func recognizePlane() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bsp = trimmed.toBSpline()
        {
            if let result = bsp.toAnalyticalWithGap(tolerance: 1e-4) {
                #expect(result.gap < 1e-3)
            }
        }
    }

    @Test("is canonical")
    func isCanonical() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(plane.isCanonical)
        }
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let trimmed = plane.trimmed(u1: -10, u2: 10, v1: -10, v2: 10),
            let bsp = trimmed.toBSpline()
        {
            #expect(!bsp.isCanonical)
        }
    }
}
