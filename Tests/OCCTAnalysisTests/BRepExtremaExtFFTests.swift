import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Expected values are the pinned kernel's answers for all 36 face pairs, measured by
/// `Scripts/repro/766-brepextrema-extff/probe.mm` (transcript alongside it).
///
/// `Shape.box(5, 5, 5)` is centred (-2.5...2.5); `Shape.box(origin: (10, 0, 0), ...)` puts its
/// corner at (10, 0, 0). Face 1 of the first box is its x = 2.5 cap and face 0 of the second is
/// its x = 10 cap, so that pair faces each other 7.5 apart.
///
/// Before #766 this test walked all 36 pairs, asserted `distance >= 0` on the first one that
/// returned anything, and never asserted that one did: a bridge returning `nil` for every pair
/// passed it.
@Suite("BRepExtrema ExtFF Tests")
struct BRepExtremaExtFFTests {
    @Test("Face-face distance between separated boxes")
    func faceFaceDistance() throws {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 5, height: 5, depth: 5)
        else {
            Issue.record("could not build the boxes")
            return
        }

        // The facing caps. BRepExtrema_ExtFF reports parallel planes as one extremum, the
        // plane-to-plane distance.
        guard let facing = box1.faceFaceExtrema(faceIndex1: 1, other: box2, faceIndex2: 0) else {
            Issue.record("the facing x caps, 7.5 apart, have an extremum")
            return
        }
        #expect(abs(facing.distance - 7.5) < 1e-12, "expected 7.5, got \(facing.distance)")
        #expect(facing.solutionCount == 1, "got \(facing.solutionCount)")
        // Not asserted: `pointOnFace1/2` and `face1UV/face2UV`. For parallel faces the kernel
        // fills no witness points, `ParameterOnFace1(1)` throws Standard_OutOfRange, and
        // OCCTBRepExtremaExtFF catches it after the distance is written, so these come back as
        // (0, 0, 0) and (0, 0). That is a bridge finding, #2249, not a value to pin.

        // A different parallel pair gives a different distance, so the index is honoured: the
        // x = -2.5 cap against the same x = 10 cap is 12.5 apart.
        if let far = box1.faceFaceExtrema(faceIndex1: 0, other: box2, faceIndex2: 0) {
            #expect(abs(far.distance - 12.5) < 1e-12, "expected 12.5, got \(far.distance)")
        } else {
            Issue.record("the x = -2.5 and x = 10 caps have an extremum")
        }

        // The negative case: two perpendicular planar faces have no extremum at all
        // (NbExt() == 0 for every non-parallel pair), so the API returns nil.
        let perpendicular = box1.faceFaceExtrema(faceIndex1: 0, other: box2, faceIndex2: 2)
        #expect(perpendicular == nil, "perpendicular planar faces have no extremum")
    }
}
