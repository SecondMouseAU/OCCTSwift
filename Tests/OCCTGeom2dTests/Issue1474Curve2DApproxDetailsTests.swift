import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `Curve2D.approximated(tolerance:continuity:maxSegments:maxDegree:)` (`OCCTCurve2DApproximate`)
/// gates its result on `Geom2dConvert_ApproxCurve::HasResult()` alone, and OCCT documents that
/// accessor as true even for a fit that is **not** within the requested `tolerance` -- "a result
/// that is not NECESSARILY within the required tolerance". Before #1474, `MaxError()` was never
/// read at all, so a caller had no way to tell a good fit from a starved one; `approximated` could
/// only ever return a curve or `nil`, never how far off that curve actually was.
///
/// `Curve3D`/`Surface` had the identical trap and were fixed by #491, which added an
/// `approxWithDetails` companion sharing one implementation with the plain entry point. #1474
/// gives `Curve2D` the same companion (`Curve2D.approxWithDetails`, backed by
/// `OCCTGeomConvertApproxCurve2D`/`OCCTApproxCurve2DResult`), rather than leaving it as a
/// doc-only warning: `Curve2D.approximated` already documents itself, in three separate places
/// (its own doc comment, `Curve3D.approximated`'s doc comment, and `Surface.approximated`'s), as
/// one of three siblings sharing the same `GeomConvert_Approx*`/`Geom2dConvert_ApproxCurve`
/// family and the same numeric defaults (#406), so leaving it as the one sibling with no
/// details-returning entry point would be the inconsistency, not the fix.
@Suite("Curve2D.approxWithDetails surfaces MaxError (#1474)")
struct Issue1474Curve2DApproxDetailsTests {

    /// The core regression proof: a fit `Geom2dConvert_ApproxCurve` completes (`HasResult`) but
    /// does not come remotely close to the requested tolerance. `approximated` alone -- the only
    /// entry point that existed before #1474 -- cannot distinguish this from a good fit; it
    /// returns a non-nil curve either way. `approxWithDetails` reports the same curve alongside
    /// the `maxError` that was previously discarded.
    ///
    /// Fixture mirrors the analogous Curve3D case in Issue491Curve3DApproxParityTests
    /// (`GeomConvert_ApproxCurve` starved at one degree-3 segment against a 1e-9 tolerance on a
    /// radius-10 circle, which measures `maxError` around 5.1 there): a single cubic segment
    /// cannot represent a full circle to anywhere near 1e-9, in 2D or 3D.
    @Test("approxWithDetails reports the true maxError for a starved (over-tolerance) fit")
    func approxWithDetailsSurfacesOverToleranceFit() {
        guard let circle = Curve2D.circle(center: .zero, radius: 10) else {
            Issue.record("circle fixture failed")
            return
        }
        let tolerance = 1e-9

        // Unchanged behavior (#1474 does not touch this entry point's gate, matching #491's
        // finding that IsDone/HasResult never actually diverge in this kernel): the plain
        // entry point still silently hands back the starved fit.
        let plain = circle.approximated(
            tolerance: tolerance, continuity: 0, maxSegments: 1, maxDegree: 3)
        #expect(plain != nil)

        let details = circle.approxWithDetails(
            tolerance: tolerance, continuity: 0, maxSegments: 1, maxDegree: 3)
        #expect(details.hasResult)
        #expect(details.curve != nil)

        // This is the number OCCTCurve2DApproximate discarded entirely before #1474. A starved
        // single-segment fit of a full circle is nowhere near a 1e-9 tolerance: measured at
        // 5.108..., matching the analogous Curve3D case's ~5.1 almost exactly. Assert it is at
        // least three orders of magnitude off, which a genuinely-converged fit never would be.
        #expect(details.maxError > tolerance * 1000)

        // Both entry points ran through the same shared implementation and must agree on the
        // fitted geometry, not just on "succeeded or not".
        if let plainPoles = plain?.poleCount, let detailsPoles = details.curve?.poleCount {
            #expect(plainPoles == detailsPoles)
        } else {
            Issue.record("expected pole counts from both entry points")
        }
    }

    /// Parity check mirroring #491's Curve3D/Surface suites: for identical arguments, the plain
    /// and detailed entry points must agree on success and on the fitted curve's shape, since
    /// #1474 puts one shared `occtApproxCurve2D` helper behind both rather than two independent
    /// `Geom2dConvert_ApproxCurve` runs that could drift.
    @Test("approximated and approxWithDetails agree on a well-converged fit")
    func approximatedAndDetailsAgreeOnGoodFit() {
        guard let circle = Curve2D.circle(center: .zero, radius: 5) else {
            Issue.record("circle fixture failed")
            return
        }
        let plain = circle.approximated(tolerance: 1e-3, continuity: 2)
        let details = circle.approxWithDetails(tolerance: 1e-3, continuity: 2)

        guard let plain, let detailsCurve = details.curve else {
            Issue.record("expected both entry points to succeed on the shared defaults")
            return
        }
        #expect(details.hasResult)
        #expect(details.maxError <= 1e-3)
        #expect(plain.poleCount == detailsCurve.poleCount)
        #expect(plain.degree == detailsCurve.degree)
    }
}
