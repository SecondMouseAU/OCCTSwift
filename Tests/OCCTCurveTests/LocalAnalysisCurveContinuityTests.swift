import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("LocalAnalysis CurveContinuity Tests")
struct LocalAnalysisCurveContinuityTests {
    // Fixture geometry (sharp-corner/smooth-junction curve pairs) moved to
    // `CurveTestFixtures.swift` as `sharpCornerCurves()`/`smoothJunctionCurves()` (#1263): this
    // file previously reimplemented both inline in all four tests below, distinctly named from the
    // shared functions since a test method here already has each name.

    @Test func smoothJunction() {
        guard let (c1, c2) = smoothJunctionCurves() else {
            Issue.record("could not build the smooth junction")  // #766: was a silent return
            return
        }
        if let analysis = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound)
        {
            #expect(analysis.isC0 == true)
            #expect(analysis.c0Value < 1e-6)
        } else {
            Issue.record("continuityWith returned nil")  // #766: was a silent skip
        }
    }

    @Test func smoothJunctionIsG1() {
        guard let (c1, c2) = smoothJunctionCurves() else {
            Issue.record("could not build the smooth junction")  // #766: was a silent return
            return
        }
        // G1 has to be requested: the `.c2` default computes C0/C1/C2 and never looks at
        // tangency, so this assertion used to pass off an uninitialised member rather than a
        // measurement (#495).
        if let analysis = c1.continuityWith(
            c2, u1: c1.domain.upperBound,
            u2: c2.domain.lowerBound, order: .g1)
        {
            #expect(analysis.isG1 == true)
            #expect(analysis.g1Angle >= 0)
            // #766: `>= 0` held for any angle. The two fits share a tangent direction at (5,0,0):
            // LocalAnalysis_CurveContinuity reports G1Angle 1.9e-17.
            #expect(analysis.g1Angle < 1e-9, "g1Angle \(analysis.g1Angle)")
        } else {
            Issue.record("continuityWith returned nil")
        }
    }

    @Test func sharpCorner() {
        guard let (c1, c2) = sharpCornerCurves() else {
            Issue.record("could not build the sharp corner")  // #766: was a silent return
            return
        }
        if let analysis = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound)
        {
            #expect(analysis.isC0 == true)
            #expect(analysis.c0Value < 1e-6)  // #766: the corner meets exactly (C0Value 0)
        } else {
            Issue.record("continuityWith returned nil")
        }
    }

    @Test func continuityMetrics() {
        guard let (c1, c2) = smoothJunctionCurves() else {
            Issue.record("could not build the smooth junction")  // #766: was a silent return
            return
        }
        if let a = c1.continuityWith(c2, u1: c1.domain.upperBound, u2: c2.domain.lowerBound) {
            // `order` is the request echoed back, so pinning it to the default is all it can
            // tell us; the measurement is `c1Ratio`, which the default order does compute.
            #expect(a.order == .c2)
            #expect(a.c1Ratio > 0)
            // #766: `> 0` held for any ratio; the two fits have equal first-derivative magnitude.
            #expect(abs(a.c1Ratio - 1) < 1e-9, "c1Ratio \(a.c1Ratio)")
        } else {
            Issue.record("continuityWith returned nil")
        }
    }
}
