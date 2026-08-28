import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeUpgrade_SplitSurface")
struct SplitSurfaceTests {
    @Test("split surface by continuity")
    func splitSurfaceByContinuity() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10) {
            if let bsp = surf.toBSpline() {
                // criterion is a ParametricContinuity raw value: 2 = C2. It used to be read
                // here as a GeomAbs_Shape ordinal, where 4 meant C2 and 2 meant C1, see
                // Issue490ContinuityDecoderTests for the cross-check against the sibling entry
                // point that always read it the other way. #490.
                let result = bsp.splitSurfaceByContinuity(criterion: 2, tolerance: 1e-6)
                // May or may not split, just verify no crash
                if let r = result {
                    #expect(r.uSplitCount >= 2)
                }
            }
        }
    }

    @Test("split by angle")
    func splitByAngle() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10) {
            if let result = surf.splitByAngle(.pi / 2) {
                #expect(result.uSplitCount >= 3)  // Full circle / 90° = 4 segments, 5 split values
            }
        }
    }

    @Test("split by area")
    func splitByArea() {
        if let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            if let trimmed = surf.trimmed(u1: 0, u2: 10, v1: 0, v2: 10) {
                let result = trimmed.splitByArea(parts: 4)
                if let r = result {
                    #expect(r.uSplitCount >= 2)
                }
            }
        }
    }
}
