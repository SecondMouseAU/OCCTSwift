import Foundation
import Testing
import simd

@testable import OCCTSwift

// #999, the Geom2d half. Two parameters that had no OCCT counterpart were replaced by the one
// each call actually has, so both are now assertable; the third was removed outright.
@Suite("Curve2D conversion and bisector parameters are live (#999)")
struct Issue999Curve2DParametersTests {

    // MARK: - toBSpline(_:) took a tolerance CurveToBSplineCurve does not have

    @Test("Each parameterisation gives a structurally different B-spline")
    func parameterisationChangesTheResult() {
        guard let circle = Curve2D.circle(center: .zero, radius: 5) else {
            Issue.record("circle fixture failed")
            return
        }
        func shape(_ p: Curve2D.Parameterisation) -> (Int, Int)? {
            guard let b = circle.toBSpline(p), let d = b.degree, let n = b.poleCount else {
                return nil
            }
            return (d, n)
        }
        // Measured against the pinned 8.0.1 kernel, and not merely "they differ": these are the
        // exact degree and pole counts the kernel produces, so a change of kernel behaviour shows
        // up here rather than being absorbed by an inequality.
        #expect(shape(.tangentHalfAngle).map { $0 == (2, 6) } == true)
        #expect(shape(.tangentHalfAngle4).map { $0 == (2, 8) } == true)
        #expect(shape(.quasiAngular).map { $0 == (6, 6) } == true)
        #expect(shape(.rationalC1).map { $0 == (4, 12) } == true)
        #expect(shape(.polynomial).map { $0 == (7, 7) } == true)
    }

    @Test("Every parameterisation but polynomial reproduces the circle exactly")
    func exactnessSeparatesPolynomialFromTheRest() {
        let radius = 5.0
        guard let circle = Curve2D.circle(center: .zero, radius: radius) else {
            Issue.record("circle fixture failed")
            return
        }
        func worstRadialError(_ p: Curve2D.Parameterisation) -> Double? {
            guard let b = circle.toBSpline(p) else { return nil }
            let d = b.domain
            var worst = 0.0
            for k in 0...200 {
                let u = d.lowerBound + (d.upperBound - d.lowerBound) * Double(k) / 200
                let pt = b.point(at: u)
                worst = max(worst, abs(simd_length(pt) - radius))
            }
            return worst
        }
        for exact in [
            Curve2D.Parameterisation.tangentHalfAngle, .tangentHalfAngle4, .quasiAngular,
            .rationalC1,
        ] {
            if let e = worstRadialError(exact) {
                #expect(e < 1e-9, "\(exact) deviated by \(e)")
            } else {
                Issue.record("\(exact) failed to convert")
            }
        }
        // Polynomial is the one OCCT documents as approximate, and it measurably is.
        if let e = worstRadialError(.polynomial) {
            #expect(e > 1e-9, "polynomial was exact, so it is no longer distinguishable")
            #expect(e < 1e-3, "polynomial deviated by \(e), far more than expected")
        } else {
            Issue.record("polynomial failed to convert")
        }
    }

    @Test("A parameterisation OCCT rejects for this arc returns nil rather than a wrong curve")
    func rejectedParameterisationReturnsNil() {
        guard let circle = Curve2D.circle(center: .zero, radius: 5) else {
            Issue.record("circle fixture failed")
            return
        }
        // A full circle spans 2 pi, past the 0.9999 pi and 1.9999 pi limits these two document.
        #expect(circle.toBSpline(.tangentHalfAngle1) == nil)
        #expect(circle.toBSpline(.tangentHalfAngle2) == nil)
    }

    // MARK: - bisector(withPoint:...) took an origin Bisector_BisecPC::Perform does not have

    @Test("The trimming distance bounds the bisector, and a longer one extends it")
    func maxDistanceTrimsTheBisector() {
        guard let line = Curve2D.line(through: .zero, direction: SIMD2(1, 0)) else {
            Issue.record("line fixture failed")
            return
        }
        var previousSpan = 0.0
        for maxDistance in [10.0, 100.0, 500.0, 5000.0] {
            guard let b = line.bisector(withPoint: SIMD2(0, 4), maxDistance: maxDistance) else {
                Issue.record("bisector failed at maxDistance \(maxDistance)")
                return
            }
            let span = b.domain.upperBound - b.domain.lowerBound
            #expect(span > previousSpan, "maxDistance \(maxDistance) did not extend the bisector")
            previousSpan = span
        }
        // The smallest trimming distance is below the point's own offset from the line, so there
        // is no bisector within it at all.
        #expect(line.bisector(withPoint: SIMD2(0, 4), maxDistance: 1) == nil)
    }
}
