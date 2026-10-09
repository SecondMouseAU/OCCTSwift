import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Cone")
struct ExtremaExtPElSConeTests {
    /// The bridge builds `gp_Cone(gp_Ax3(apex, axis), semiAngle, refRadius)`, and gp_Cone's
    /// location is the centre of its reference circle, not the apex: with refRadius 5 and a
    /// 45 degree half-angle the true apex is at z = -5, and the generator in the +X half of the
    /// XZ plane is x = z + 5. The point (20, 0, 0) is 15 / sqrt(2) from that line, with foot
    /// (12.5, 0, 7.5); the second extremum is on the lower nappe, (7.5, 0, -12.5), at squared
    /// distance 312.5. The pinned kernel returns both, in that order
    /// (`Scripts/repro/766-extrema-extpels-cone/probe.mm`, transcript alongside it).
    ///
    /// Before #766 this asserted `results.count > 0`, which a bridge returning any extremum at
    /// all, anywhere, passed.
    @Test func pointToCone() {
        let results = ExtremaPointSurface.pointToCone(
            point: SIMD3(20, 0, 0),
            apex: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 4, refRadius: 5
        )
        #expect(results.count == 2, "got \(results.count)")
        guard results.count == 2 else { return }

        #expect(abs(results[0].squareDistance - 112.5) < 1e-9, "got \(results[0].squareDistance)")
        #expect(simd_distance(results[0].point1, SIMD3(20, 0, 0)) < 1e-12, "point1 is the query point")
        #expect(
            simd_distance(results[0].point2, SIMD3(12.5, 0, 7.5)) < 1e-9,
            "nearest foot expected (12.5, 0, 7.5), got \(results[0].point2)")

        #expect(abs(results[1].squareDistance - 312.5) < 1e-9, "got \(results[1].squareDistance)")
        #expect(
            simd_distance(results[1].point2, SIMD3(7.5, 0, -12.5)) < 1e-9,
            "lower-nappe foot expected (7.5, 0, -12.5), got \(results[1].point2)")
    }
}
