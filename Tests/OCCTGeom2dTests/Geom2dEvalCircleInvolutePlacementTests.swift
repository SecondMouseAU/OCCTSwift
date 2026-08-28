import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval — Circle Involute with Placement")
struct Geom2dEvalCircleInvolutePlacementTests {

    @Test func involuteD0WithPlacementAtOrigin() {
        let p = Geom2dEval.circleInvoluteD0(
            origin: .zero, direction: SIMD2(1, 0), radius: 2.0, u: 0.0)
        // C(0) = O + R*(1, 0) = (2, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func involuteD0WithPlacementTranslated() {
        let p = Geom2dEval.circleInvoluteD0(
            origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0, u: 0.0)
        // C(0) = (10, 20) + 2*(1, 0) = (12, 20)
        #expect(abs(p.x - 12.0) < 1e-10)
        #expect(abs(p.y - 20.0) < 1e-10)
    }

    @Test func involuteD0WithPlacementRotated() {
        let angle = Double.pi / 2  // 90 degrees
        let dir = SIMD2(cos(angle), sin(angle))  // (0, 1)
        let p = Geom2dEval.circleInvoluteD0(origin: .zero, direction: dir, radius: 2.0, u: 0.0)
        // C(0) = O + R*(0, 1) = (0, 2)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 2.0) < 1e-10)
    }

    @Test func involuteD0PlacementDiffersFromIdentity() {
        // Test that non-identity placement produces different results from the hardcoded identity
        let pIdentity = Geom2dEval.circleInvoluteD0(radius: 2.0, u: 1.0)
        let pPlaced = Geom2dEval.circleInvoluteD0(
            origin: SIMD2(5, 5), direction: SIMD2(0, 1), radius: 2.0, u: 1.0)
        // Results should differ because placement is different
        #expect(abs(pIdentity.x - pPlaced.x) > 1e-10 || abs(pIdentity.y - pPlaced.y) > 1e-10)
    }

    @Test func involuteD1WithPlacement() {
        let r = Geom2dEval.circleInvoluteD1(
            origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0, u: 1.0)
        let speed = sqrt(r.d1.x * r.d1.x + r.d1.y * r.d1.y)
        #expect(speed > 0)  // |D1(t)| = R*t
    }
}
