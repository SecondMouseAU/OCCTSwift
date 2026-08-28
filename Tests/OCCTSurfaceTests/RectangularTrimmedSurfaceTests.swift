import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_RectangularTrimmedSurface Tests")
struct RectangularTrimmedSurfaceTests {
    @Test func trimPlane() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        let trimmed = Surface.rectangularTrimmed(
            basis: plane,
            u1: -5, u2: 5, v1: -3, v2: 3)
        #expect(trimmed != nil)
    }

    @Test func trimInU() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        let trimmed = Surface.trimmedInU(basis: plane, param1: -2, param2: 2)
        #expect(trimmed != nil)
    }

    @Test func trimInV() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        let trimmed = Surface.trimmedInV(basis: plane, param1: -3, param2: 3)
        #expect(trimmed != nil)
    }
}
