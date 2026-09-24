import Foundation
import Testing
import simd

@testable import OCCTSwift

/// A distance-angle chamfer of distance d at angle a on a box edge cuts off a triangular prism
/// with legs d and d * tan(a) along the whole edge, so on the centred 10-unit box the result
/// has volume 1000 - 0.5 * d * d * tan(a) * 10 and seven faces. The pinned kernel gives exactly
/// that (`Scripts/repro/766-dist-angle-chamfer/probe.mm`, transcript alongside it).
///
/// Before #766 these tests asserted `result != nil` and, for 45 degrees, `isValid`. A bridge that
/// ignored the angle, or converted degrees to radians wrongly, still produced a valid chamfer and
/// passed; pinning the volume is what makes the angle observable.
@Suite("Distance-Angle Chamfer")
struct DistAngleChamferTests {

    /// Chamfers `Shape.box(10, 10, 10)`'s edge 0 on face 0 with distance 1 and checks the
    /// result's validity, face count and volume against the closed form.
    ///
    /// Each precondition is a `try #require`, not an `Issue.record` plus `return`: a nil box,
    /// chamfer or volume records the failure and throws, so the test stops at the guard and
    /// never reaches the `#expect`s below it with nothing to measure.
    private func checkChamfer(angleDegrees: Double) throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(
            box.chamferedDistAngle([
                (edgeIndex: 0, faceIndex: 0, distance: 1.0, angleDegrees: angleDegrees)
            ]),
            "a 1-unit chamfer at \(angleDegrees) degrees on a 10-unit box succeeds")
        #expect(r.isValid)
        #expect(r.faces().count == 7, "one chamfer face added to six, got \(r.faces().count)")
        let expected = 1000.0 - 0.5 * 1.0 * 1.0 * tan(angleDegrees * .pi / 180.0) * 10.0
        let v = try #require(r.volume, "a chamfered box has a volume")
        #expect(abs(v - expected) < 1e-9, "at \(angleDegrees) degrees expected \(expected), got \(v)")
    }

    @Test("Distance-angle chamfer on box edge")
    func distAngleChamfer() throws {
        try checkChamfer(angleDegrees: 45.0)  // probed 994.99999999999977
    }

    @Test("Distance-angle chamfer at 30 degrees")
    func distAngle30() throws {
        try checkChamfer(angleDegrees: 30.0)  // probed 997.11324865405163
    }

    @Test("Distance-angle chamfer at 60 degrees")
    func distAngle60() throws {
        try checkChamfer(angleDegrees: 60.0)  // probed 991.33974596215546
    }
}
