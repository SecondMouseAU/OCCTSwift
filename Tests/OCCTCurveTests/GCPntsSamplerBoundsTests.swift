import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #501: GCPnts samplers can compute more points than were requested

/// An ellipse whose arc-length walk lands short of the end by more than the sampler will accept,
/// so `GCPnts_UniformAbscissa` takes one extra step and snaps it to the end parameter. That
/// surplus point used to be written past the end of the caller's buffer; clamping it away without
/// keeping the sampler's last point would instead leave the distribution stopping short of the
/// curve.
///
/// **#2977 re-pointed this fixture.** #501's own 1e6 x 1e-3 ellipse no longer overshoots: carried
/// patch `0018` also accepts a step within `theTol` of the end in 3D, and at that size the
/// leftover gap is inside it. A 1e8 x 0.1 ellipse still overshoots, because the same relative
/// shortfall is a hundred times further in model space. Measured 2026-10-02 against
/// `v4.0.0-kernel.3`, 2D and 3D and both samplers, with the same eight counts in all four
/// combinations; the transcript is in `Scripts/repro/2977-uniformabscissa-no-overshoot/`. The
/// shortfall here is 5.43e-8 in parameter and 1.5e-7 in model space, so the `1e-12` parameter
/// tolerance below separates the sampler's last point from its last-but-one by five orders of
/// magnitude.
private func overshootingEllipse() -> Curve3D? {
    Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 1e8, minorRadius: 0.1)
}

/// The counts that still overshoot on that ellipse, eight of the first 59, measured on
/// `v4.0.0-kernel.3`. Six of the eight, because each call costs about 1.4 s on this curve.
private let overshootingCounts = [24, 34, 35, 41, 47, 51]

/// #501's original fixture, as a control: the same counts on a curve the pinned kernel samples
/// exactly, where the clamp is a no-op and the end arrives in the last slot regardless (#2977).
private func settledEllipse() -> Curve3D? {
    Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 1e6, minorRadius: 1e-3)
}

@Suite("GCPnts sampler bounds (#501)")
struct GCPntsSamplerBoundsTests {
    @Test("Quasi-uniform sampling never exceeds the requested count")
    func quasiUniformRespectsCount() throws {
        let ellipse = try #require(overshootingEllipse())
        for count in overshootingCounts {
            #expect(ellipse.quasiUniformParameters(count: count).count == count)
        }
    }

    @Test("Quasi-uniform sampling still reaches the end of the curve when clamped")
    func quasiUniformKeepsCurveEnd() throws {
        // #2977: `if let last = params.last` skipped every assertion on an empty sample, and an
        // empty sample is exactly what a clamp that returns nothing produces. Required and
        // indexed instead.
        let ellipse = try #require(overshootingEllipse())
        let end = ellipse.domain.upperBound
        for count in overshootingCounts {
            let params = ellipse.quasiUniformParameters(count: count)
            try #require(params.count == count)
            #expect(abs(params[count - 1] - end) < 1e-12)
        }
    }

    @Test("Quasi-uniform parameters stay ordered when clamped")
    func quasiUniformStaysOrdered() throws {
        let ellipse = try #require(overshootingEllipse())
        for count in overshootingCounts {
            let params = ellipse.quasiUniformParameters(count: count)
            // #2977: an empty or short result made the loop body unreachable, so the case passed
            // on a sampler that returned nothing at all.
            try #require(params.count == count)
            for i in 1..<params.count {
                #expect(params[i] > params[i - 1])
            }
        }
    }

    @Test("Uniform discretization never exceeds the requested count and reaches the end")
    func drawUniformRespectsCount() throws {
        let ellipse = try #require(overshootingEllipse())
        let endPoint = ellipse.point(at: ellipse.domain.upperBound)
        for count in overshootingCounts {
            let points = ellipse.drawUniform(pointCount: count)
            try #require(points.count == count)
            // 1e-9, not the 1e-6 this carried while its fixture did not overshoot: the sampler's
            // last-but-one point is 1.5e-7 from the end on this curve, so 1e-6 would accept the
            // very defect the case exists for (#2977). The kept end point is the same double
            // evaluated twice, so the distance is 0.
            #expect(distance(points[count - 1], endPoint) < 1e-9)
        }
    }

    /// The control for the three cases above: #501's own ellipse, which the pinned kernel samples
    /// exactly, at the same counts. Everything the overshooting fixture asserts has to hold here
    /// too, and does so without the clamp or the last-slot rule doing any work (#2977).
    @Test("A curve the sampler gets exactly still clamps and ends on the curve")
    func settledEllipseBehavesIdentically() throws {
        let ellipse = try #require(settledEllipse())
        let end = ellipse.domain.upperBound
        let endPoint = ellipse.point(at: end)
        for count in overshootingCounts {
            let params = ellipse.quasiUniformParameters(count: count)
            try #require(params.count == count)
            #expect(abs(params[count - 1] - end) < 1e-12)
            let points = ellipse.drawUniform(pointCount: count)
            try #require(points.count == count)
            #expect(distance(points[count - 1], endPoint) < 1e-9)
        }
    }

    /// OCCT documents `nbPoints >= 2` for both samplers but enforces it with a `Raise_if`, which
    /// the Release kernel compiles out (No_Exception, #487). Below 2 the algorithms do not fail
    /// cleanly: `GCPnts_QuasiUniformAbscissa(bezier_or_bspline, 0)` writes element 1 of an
    /// empty `(1, 0)`-ranged array and SIGSEGVs, so every entry point rejects it itself.
    @Test("Sample counts below two are rejected, not passed to OCCT")
    func countsBelowTwoRejected() {
        guard let ellipse = overshootingEllipse(),
            let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5),
            let bezier = Curve3D.bezier(poles: [
                SIMD3(0, 0, 0), SIMD3(1, 4, 0),
                SIMD3(4, -3, 1), SIMD3(6, 1, 0),
            ])
        else {
            Issue.record("could not build the degenerate-count fixtures")
            return
        }
        for curve in [ellipse, circle, bezier] {
            for count in [0, 1] {
                #expect(curve.quasiUniformParameters(count: count).isEmpty)
                #expect(curve.drawUniform(pointCount: count).isEmpty)
            }
        }
    }

    @Test("Edge uniform abscissa rejects counts below two")
    func edgeUniformAbscissaRejectsCountsBelowTwo() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let edge = box.subShapes(ofType: .edge).first
        else {
            Issue.record("could not build a box edge")
            return
        }
        for count in [0, 1] {
            #expect(edge.uniformAbscissa(pointCount: count) == nil)
            #expect(edge.uniformAbscissa(pointCount: count, u1: 0, u2: 1) == nil)
        }
    }
}
