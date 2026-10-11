import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna LineTorus Tests")
struct IntAnaLineTorusTests {

    /// The x axis meets the torus at four points.
    ///
    /// #1740: this asserted `pts.count >= 2`, which a result missing half its points, or carrying
    /// points anywhere at all, also satisfies. The x axis crosses a torus of major radius 20 and
    /// minor radius 5, centred on the origin with axis z, where the tube meets it: x = +-15 and
    /// x = +-25. IntAna_IntLinTorus reports those four (`Scripts/repro/766-intana-line-torus/`);
    /// their order is not part of the contract, so they are compared sorted by x.
    @Test func lineThroughTorus() {
        let pts = IntAna.lineTorus(
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0),
            torusCenter: SIMD3(0, 0, 0), torusAxis: SIMD3(0, 0, 1),
            majorRadius: 20, minorRadius: 5)
        #expect(pts.count == 4)
        let expected: [SIMD3<Double>] = [
            SIMD3(-25, 0, 0), SIMD3(-15, 0, 0), SIMD3(15, 0, 0), SIMD3(25, 0, 0),
        ]
        for (p, e) in zip(pts.sorted { $0.x < $1.x }, expected) {
            #expect(simd_distance(p, e) < 1e-9, "got \(p), expected \(e)")
        }
    }
}
