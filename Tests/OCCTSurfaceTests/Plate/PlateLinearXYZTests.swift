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

    /// #1583: `targets`/`coefficients` shorter than `uvPoints` used to be read past their end
    /// inside the bridge loop (`targets[i*3+0..2]`/`coeffs[i]` for `i` up to `uvPoints.count`).
    ///
    /// Now rejected up front, for either array, in either direction.
    @Test func loadLinearXYZLengthMismatchIsRejected() {
        let uvs = [SIMD2(0.0, 0.0), SIMD2(1.0, 0.0), SIMD2(0.5, 1.0)]
        let matchingTargets = [
            SIMD3(0.0, 0.0, 1.0), SIMD3(0.0, 0.0, 1.0), SIMD3(0.0, 0.0, 1.0),
        ]
        let matchingCoeffs = [1.0, -1.0, 1.0]

        let plateShortTargets = PlateSolver()
        #expect(
            !plateShortTargets.loadLinearXYZ(
                uvPoints: uvs,
                targets: [SIMD3(0.0, 0.0, 1.0)],
                coefficients: matchingCoeffs))

        let plateLongTargets = PlateSolver()
        #expect(
            !plateLongTargets.loadLinearXYZ(
                uvPoints: uvs,
                targets: matchingTargets + [SIMD3(0.0, 0.0, 1.0)],
                coefficients: matchingCoeffs))

        let plateShortCoeffs = PlateSolver()
        #expect(
            !plateShortCoeffs.loadLinearXYZ(
                uvPoints: uvs, targets: matchingTargets, coefficients: [1.0]))

        let plateLongCoeffs = PlateSolver()
        #expect(
            !plateLongCoeffs.loadLinearXYZ(
                uvPoints: uvs, targets: matchingTargets, coefficients: matchingCoeffs + [1.0]))
    }
}
