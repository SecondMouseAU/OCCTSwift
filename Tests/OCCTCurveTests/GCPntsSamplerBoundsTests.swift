import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #501: GCPnts samplers can compute more points than were requested

/// An ellipse whose arc-length walk lands ~1.6e-8 in parameter short of the end, so
/// `GCPnts_UniformAbscissa` takes one extra step and snaps it to the end parameter. That surplus
/// point used to be written past the end of the caller's buffer; clamping it away without keeping
/// the sampler's last point would instead leave the distribution stopping short of the curve.
fileprivate func overshootingEllipse() -> Curve3D? {
    Curve3D.ellipse(center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 1e6, minorRadius: 1e-3)
}

/// Counts measured to overshoot on that ellipse (22 of the first 59 do).
fileprivate let overshootingCounts = [4, 5, 8, 12, 14, 18, 20, 22, 25, 26, 31, 33, 34, 35, 39, 40]

@Suite("GCPnts sampler bounds (#501)")
struct GCPntsSamplerBoundsTests {
    @Test("Quasi-uniform sampling never exceeds the requested count")
    func quasiUniformRespectsCount() {
        guard let ellipse = overshootingEllipse() else {
            Issue.record("could not build the high-aspect-ratio ellipse")
            return
        }
        for count in overshootingCounts {
            #expect(ellipse.quasiUniformParameters(count: count).count == count)
        }
    }

    @Test("Quasi-uniform sampling still reaches the end of the curve when clamped")
    func quasiUniformKeepsCurveEnd() {
        guard let ellipse = overshootingEllipse() else { return }
        let end = ellipse.domain.upperBound
        for count in overshootingCounts {
            let params = ellipse.quasiUniformParameters(count: count)
            if let last = params.last {
                #expect(abs(last - end) < 1e-12)
            }
        }
    }

    @Test("Quasi-uniform parameters stay ordered when clamped")
    func quasiUniformStaysOrdered() {
        guard let ellipse = overshootingEllipse() else { return }
        for count in overshootingCounts {
            let params = ellipse.quasiUniformParameters(count: count)
            for i in 1..<params.count {
                #expect(params[i] > params[i - 1])
            }
        }
    }

    @Test("Uniform discretization never exceeds the requested count and reaches the end")
    func drawUniformRespectsCount() {
        guard let ellipse = overshootingEllipse() else { return }
        let endPoint = ellipse.point(at: ellipse.domain.upperBound)
        for count in overshootingCounts {
            let points = ellipse.drawUniform(pointCount: count)
            #expect(points.count == count)
            if let last = points.last {
                #expect(distance(last, endPoint) < 1e-6)
            }
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
