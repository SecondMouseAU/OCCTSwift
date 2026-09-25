import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_LocateExtCC Tests")
struct ExtremaLocateExtCCTests {
    /// A radius-5 circle in the XY plane and a line through (10, 0, 3) along Y. Seeded at u = 0
    /// (circle point (5, 0, 0)) and v = 0 (line point (10, 0, 3)), the local extremum is that
    /// pair: square distance 5^2 + 3^2 = 34. The pinned kernel returns exactly that
    /// (`Scripts/repro/766-extrema-locate-extcc/probe.mm`, transcript alongside it).
    ///
    /// Before #766 this asserted `dist > 0` inside `if let` on both curves, so any positive
    /// distance passed, and it never read the points or parameters.
    @Test func localExtremum() {
        guard let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0),
            let line = Curve3D.line(through: SIMD3(10, 0, 3), direction: SIMD3(0, 1, 0))
        else {
            Issue.record("could not build the circle or the line")
            return
        }
        let result = circ.locateExtremaCC(
            range1: 0...(.pi * 2), other: line,
            range2: -10...10, seedU: 0, seedV: 0)
        #expect(result.isDone)
        #expect(abs(result.squareDistance - 34) < 1e-12, "expected 34, got \(result.squareDistance)")
        #expect(simd_distance(result.point1, SIMD3(5, 0, 0)) < 1e-12, "p1 got \(result.point1)")
        #expect(abs(result.param1) < 1e-12, "param1 got \(result.param1)")
        #expect(simd_distance(result.point2, SIMD3(10, 0, 3)) < 1e-12, "p2 got \(result.point2)")
        #expect(abs(result.param2) < 1e-12, "param2 got \(result.param2)")
    }
}
