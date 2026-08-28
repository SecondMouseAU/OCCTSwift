import Testing
import simd

@testable import OCCTSwift

@Suite("Plate LinearXYZ Constraint")
struct PlateLinearXYZTests {
    @Test func loadLinearXYZ() {
        let plate = PlateSolver()
        let uvs = [SIMD2(0.0, 0.0), SIMD2(1.0, 0.0)]
        let targets = [SIMD3(0.0, 0.0, 1.0), SIMD3(0.0, 0.0, 1.0)]
        let coeffs = [1.0, -1.0]
        #expect(plate.loadLinearXYZ(uvPoints: uvs, targets: targets, coefficients: coeffs))
    }
}
