import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GeomConvert_CompCurveToBSplineCurve on the same segments
// (Scripts/repro/766-curve-join-length-split/transcript.txt). The earlier versions sat inside
// `if let joined`, so a nil join passed with nothing checked, and allowed 0.01 of slack (#766).
@Suite("GeomConvert CompCurveToBSpline Tests")
struct CurveJoinTests {
    private static func check(_ joined: Curve3D?, _ start: SIMD3<Double>, _ end: SIMD3<Double>,
                              length: Double) {
        guard let joined else {
            Issue.record("join returned nil")
            return
        }
        let dom = joined.domain
        #expect(simd_distance(joined.point(at: dom.lowerBound), start) < 1e-12)
        #expect(simd_distance(joined.point(at: dom.upperBound), end) < 1e-12)
        // The joined BSpline is parameterised by length along its segments.
        #expect(abs(dom.upperBound - dom.lowerBound - length) < 1e-12)
    }

    @Test("Join two line segments")
    func joinTwoSegments() throws {
        guard let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0)),
            let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))
        else {
            Issue.record("segments not built")
            return
        }
        Self.check(Curve3D.joined(curves: [seg1, seg2]), SIMD3(0, 0, 0), SIMD3(2, 1, 0),
                   length: 1 + 2.0.squareRoot())
    }

    @Test("Join three segments")
    func joinThreeSegments() throws {
        guard let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0)),
            let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0)),
            let seg3 = Curve3D.segment(from: SIMD3(2, 1, 0), to: SIMD3(3, 1, 1))
        else {
            Issue.record("segments not built")
            return
        }
        Self.check(Curve3D.joined(curves: [seg1, seg2, seg3]), SIMD3(0, 0, 0), SIMD3(3, 1, 1),
                   length: 1 + 2 * 2.0.squareRoot())
    }

    @Test("Join single curve")
    func joinSingleCurve() throws {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0)) else {
            Issue.record("segment not built")
            return
        }
        Self.check(Curve3D.joined(curves: [seg]), SIMD3(0, 0, 0), SIMD3(5, 0, 0), length: 5)
    }
}
