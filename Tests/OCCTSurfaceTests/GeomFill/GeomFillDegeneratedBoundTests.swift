import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill DegeneratedBound")
struct GeomFillDegeneratedBoundTests {
    @Test func degeneratedBoundaryValue() {
        let val = Surface.degeneratedBoundaryValue(
            point: SIMD3(1, 2, 3), parameter: 0.5)
        #expect(abs(val.x - 1.0) < 1e-6)
        #expect(abs(val.y - 2.0) < 1e-6)
        #expect(abs(val.z - 3.0) < 1e-6)
    }

    @Test func isDegenerated() {
        let result = Surface.isDegeneratedBoundary(point: SIMD3(1, 2, 3))
        #expect(result)
    }
}
