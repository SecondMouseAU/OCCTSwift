import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #853: `Shape.uniformAbscissa(distance:)` and `uniformAbscissa(distance:u1:u2:)` had no
/// ceiling at all. Their `pointCount:` siblings reject an unservable request through
/// `Sampling.requested` before the bridge ever runs; the two `distance:` overloads had no
/// caller-supplied count to check and sized their Swift allocation directly off whatever count
/// the bridge's own sizing call reported, no bound of any kind.
///
/// The fix derives the *implied* count (curve length / distance) in Swift and rejects it before
/// calling into OCCT at all, mirroring `ArcLengthCurveAdaptor.points(spacing:)` (#479). That keeps
/// this test cheap: on the shipped (unfixed) code, `uniformAbscissa(distance:)` with a spacing
/// implying millions of points actually asks `GCPnts_UniformAbscissa` to discretize that many,
/// the same 4.5µs/point, ~24-byte/point cost `Sampling.maximumSampleCount`'s own doc quotes for
/// the ceiling itself (multiple seconds, hundreds of MB), which is why the chosen spacing below
/// implies only modestly past the ceiling rather than the 1e10+ points a truly pathological
/// distance would ask for.
@Suite("Issue #853: uniformAbscissa(distance:) gains the ceiling its pointCount sibling always had")
struct Issue853UniformAbscissaDistanceCeiling {

    private func boxEdge() -> Shape {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        return box.subShapes(ofType: .edge).first!
    }

    @Test("a distance implying more points than the ceiling returns nil, both overloads")
    func distancePastCeilingIsNil() {
        let edge = boxEdge()
        // Whole-edge spacing: length 10, so ceiling+~1000 points is rejected before OCCT runs.
        let wholeLength = edge.edgeArcLength
        let tinySpacing = wholeLength / Double(Sampling.maximumSampleCount + 1_000)
        #expect(edge.uniformAbscissa(distance: tinySpacing) == nil)

        // Ranged spacing: [u1, u2] doesn't have to cover the whole edge (and on a box edge's own
        // parametrization, [0, 1] doesn't), so the spacing is derived from the *measured* range
        // length via the already-tested edgeArcLength(from:to:), not assumed from the whole edge.
        let rangeLength = edge.edgeArcLength(from: 0, to: 1)
        #expect(rangeLength > 0)
        let tinyRangedSpacing = rangeLength / Double(Sampling.maximumSampleCount + 1_000)
        #expect(edge.uniformAbscissa(distance: tinyRangedSpacing, u1: 0, u2: 1) == nil)
    }

    @Test("a non-positive or non-finite distance returns nil without reaching the ceiling check")
    func nonPositiveDistanceIsNil() {
        let edge = boxEdge()
        #expect(edge.uniformAbscissa(distance: 0) == nil)
        #expect(edge.uniformAbscissa(distance: -1) == nil)
        #expect(edge.uniformAbscissa(distance: .nan) == nil)
        #expect(edge.uniformAbscissa(distance: 0, u1: 0, u2: 1) == nil)
        #expect(edge.uniformAbscissa(distance: -1, u1: 0, u2: 1) == nil)
    }

    @Test("a plausible distance is unaffected by the new ceiling check, both overloads")
    func ordinaryDistanceStillWorks() {
        let edge = boxEdge()
        let params = edge.uniformAbscissa(distance: 3.0)
        #expect(params != nil)
        if let params = params { #expect(params.count >= 2) }

        let ranged = edge.uniformAbscissa(distance: 0.2, u1: 0, u2: 1)
        #expect(ranged != nil)
        if let ranged = ranged { #expect(ranged.count >= 2) }
    }

    @Test("pointCount and its range sibling are unaffected by sharing the new helper")
    func pointCountOverloadsUnaffected() {
        let edge = boxEdge()
        #expect(edge.uniformAbscissa(pointCount: 5)?.count == 5)
        #expect(edge.uniformAbscissa(pointCount: 3, u1: 0, u2: 1)?.count == 3)
        #expect(edge.uniformAbscissa(pointCount: 1) == nil)
        #expect(edge.uniformAbscissa(pointCount: Sampling.maximumSampleCount + 1) == nil)
    }
}
