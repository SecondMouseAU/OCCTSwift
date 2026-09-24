import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Cylinder")
struct ExtremaElCSLinCylTests {
    // #766: this asserted `results.count >= 0`, which no `Array` can fail. Its line is parallel
    // to the cylinder axis, the case `OCCTExtremaElCSLinCylinder` answers with no extrema
    // without calling the kernel: `Extrema_ExtElCS::NbExt()` on this input still dies of
    // SIGSEGV on the pinned 8.0.1 kernel, in a probe's child process
    // (Scripts/repro/766-extremaelcslincyl). The empty result is now asserted, so this test is
    // the one that fails if that guard goes.
    @Test func lineCylinderDistance() {
        let results = ExtremaElCS.lineToCylinder(
            linePoint: SIMD3(20, 0, 0), lineDir: SIMD3(0, 0, 1),
            cylCenter: SIMD3(0, 0, 0), cylAxis: SIMD3(0, 0, 1), cylRadius: 5
        )
        #expect(results.isEmpty)
    }

    // The measurable case beside it: a line 20 from the axis and perpendicular to it. The
    // kernel reports two extrema, both at the line's closest point (20, 0, 0): the near side of
    // the cylinder at (5, 0, 0), squared distance 225, and the far side at (-5, 0, 0), 625.
    @Test func lineCylinderDistancePerpendicular() {
        let results = ExtremaElCS.lineToCylinder(
            linePoint: SIMD3(20, 0, 0), lineDir: SIMD3(0, 1, 0),
            cylCenter: SIMD3(0, 0, 0), cylAxis: SIMD3(0, 0, 1), cylRadius: 5
        )
        #expect(results.count == 2)
        let near = results.min { $0.squareDistance < $1.squareDistance }
        let far = results.max { $0.squareDistance < $1.squareDistance }
        if let near, let far {
            #expect(abs(near.squareDistance - 225) < 1e-9)
            #expect(simd_distance(near.point1, SIMD3(20, 0, 0)) < 1e-9)
            #expect(simd_distance(near.point2, SIMD3(5, 0, 0)) < 1e-9)
            #expect(abs(far.squareDistance - 625) < 1e-9)
            #expect(simd_distance(far.point2, SIMD3(-5, 0, 0)) < 1e-9)
        }
    }
}
