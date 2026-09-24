import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Sphere")
struct ExtremaElCSLinSphereTests {
    /// Both line-sphere extrema, pinned to the kernel values.
    ///
    /// The line z = 20 along X against the r = 5 sphere at the origin. The version of this test
    /// before #1810 asserted only `results.count > 0`, which any result at all satisfies. Pinned
    /// to the kernel's two extrema, in its order: the near pole (0, 0, 5) at distance 15 and the
    /// far pole (0, 0, -5) at distance 25, both from the line point (0, 0, 20)
    /// (Scripts/repro/766-extrema-elcs-lin-sphere-tests/transcript.txt).
    @Test func lineSphereDistance() {
        let results = ExtremaElCS.lineToSphere(
            linePoint: SIMD3(0, 0, 20), lineDir: SIMD3(1, 0, 0),
            sphereCenter: SIMD3(0, 0, 0), sphereRadius: 5
        )
        #expect(
            results.count == 2,
            "a line misses a sphere with a near and a far extremum, got \(results.count)")
        guard results.count == 2 else { return }

        #expect(
            abs(results[0].squareDistance - 225) < 1e-9,
            "near: distance 15, got \(results[0].squareDistance.squareRoot())")
        #expect(simd_distance(results[0].point1, SIMD3(0, 0, 20)) < 1e-9)
        #expect(simd_distance(results[0].point2, SIMD3(0, 0, 5)) < 1e-9)

        #expect(
            abs(results[1].squareDistance - 625) < 1e-9,
            "far: distance 25, got \(results[1].squareDistance.squareRoot())")
        #expect(simd_distance(results[1].point1, SIMD3(0, 0, 20)) < 1e-9)
        #expect(simd_distance(results[1].point2, SIMD3(0, 0, -5)) < 1e-9)
    }
}
