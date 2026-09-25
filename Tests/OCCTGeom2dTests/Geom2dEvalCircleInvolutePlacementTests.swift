import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Circle Involute with Placement")
struct Geom2dEvalCircleInvolutePlacementTests {

    @Test func involuteD0WithPlacementAtOrigin() throws {
        let p = try #require(
            Geom2dEval.circleInvoluteD0(
                origin: .zero, direction: SIMD2(1, 0), radius: 2.0, u: 0.0))
        // C(0) = O + R*(1, 0) = (2, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func involuteD0WithPlacementTranslated() throws {
        let p = try #require(
            Geom2dEval.circleInvoluteD0(
                origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0, u: 0.0))
        // C(0) = (10, 20) + 2*(1, 0) = (12, 20)
        #expect(abs(p.x - 12.0) < 1e-10)
        #expect(abs(p.y - 20.0) < 1e-10)
    }

    @Test func involuteD0WithPlacementRotated() throws {
        let angle = Double.pi / 2  // 90 degrees
        let dir = SIMD2(cos(angle), sin(angle))  // (0, 1)
        let p = try #require(
            Geom2dEval.circleInvoluteD0(origin: .zero, direction: dir, radius: 2.0, u: 0.0))
        // C(0) = O + R*(0, 1) = (0, 2)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 2.0) < 1e-10)
    }

    @Test func involuteD0PlacementDiffersFromIdentity() throws {
        // Test that non-identity placement produces different results from the hardcoded identity
        let pIdentity = try #require(Geom2dEval.circleInvoluteD0(radius: 2.0, u: 1.0))
        let pPlaced = try #require(
            Geom2dEval.circleInvoluteD0(
                origin: SIMD2(5, 5), direction: SIMD2(0, 1), radius: 2.0, u: 1.0))
        // Results should differ because placement is different. #1979: "differ" passed any wrong
        // placement; both are now pinned to Geom2dEval_CircleInvoluteCurve
        // (Scripts/repro/766-geom2d-eval-involute-logspiral/).
        #expect(abs(pIdentity.x - pPlaced.x) > 1e-10 || abs(pIdentity.y - pPlaced.y) > 1e-10)
        #expect(simd_distance(pIdentity, SIMD2(2.76354658135, 0.60233735788)) < 1e-9)
        #expect(simd_distance(pPlaced, SIMD2(4.39766264212, 7.76354658135)) < 1e-9)
    }

    @Test func involuteD1WithPlacement() throws {
        let r = try #require(
            Geom2dEval.circleInvoluteD1(
                origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0, u: 1.0))
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(abs(speed - 2) < 1e-9)  // |D1(t)| = R*t
        // #1979: `speed > 0` passed any derivative; D1 = R t (cos t, sin t) and the point is pinned.
        #expect(simd_distance(r.d1, SIMD2(1.08060461174, 1.68294196962)) < 1e-9)
        #expect(simd_distance(r.point, SIMD2(12.7635465814, 20.6023373579)) < 1e-9)
    }
}
