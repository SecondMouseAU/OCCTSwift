import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna ConeSphere Tests")
struct IntAnaConeSphereTests {

    @Test func coneSphereIntersection() {
        let count = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        #expect(count != nil)
        if let c = count {
            #expect(c >= 0)
        }
    }

    @Test func coneSphereSamplePoints() {
        let count = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        if let c = count, c > 0 {
            let pts = QuadricIntersection.coneSpherePoints(
                semiAngle: .pi / 4, refRadius: 0,
                sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3,
                curveIndex: 1, sampleCount: 10)
            #expect(pts.count >= 0)
        }
    }

    // #1495: `t = first + (last - first) * i / (actual - 1)` divides by zero when `nbSamples ==
    // 1`, producing NaN while still reporting success. `Sampling.requested(_:atLeast:)` is
    // called with `atLeast: 1` from `coneSpherePoints`, which documents `sampleCount: 1` as
    // legal, so the fix is to special-case it (single sample at the curve's domain start), not
    // reject it, matching `OCCTEdgeGetPoints`'s identical `(count == 1) ? first : ...` guard.
    //
    // The fixture matters: every other test in this file uses a sphere centered ON the cone's
    // axis (`SIMD3(0, 0, 5)`), which this specific cone/sphere pair reports as `curveCount == 0`
    // (measured directly against `IntAna_IntQuadQuad`, not assumed), so `coneSpherePoints` never
    // even reaches the division and a test built on it would pass vacuously either way. An
    // off-axis sphere center makes the cone genuinely pierce the sphere (`curveCount == 2`).
    @Test func singleSampleIsNotNaN() {
        let count = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(3, 0, 5), sphereRadius: 2)
        #expect(count == 2)
        let pts = QuadricIntersection.coneSpherePoints(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(3, 0, 5), sphereRadius: 2,
            curveIndex: 1, sampleCount: 1)
        #expect(pts.count == 1)
        if let p = pts.first {
            #expect(!p.x.isNaN)
            #expect(!p.y.isNaN)
            #expect(!p.z.isNaN)
            // The single sample lands at the curve's domain start, per coneSpherePoints' contract.
            let atFirst = QuadricIntersection.coneSpherePoints(
                semiAngle: .pi / 4, refRadius: 0,
                sphereCenter: SIMD3(3, 0, 5), sphereRadius: 2,
                curveIndex: 1, sampleCount: 2)
            #expect(atFirst.count == 2)
            if let expected = atFirst.first {
                #expect(abs(p.x - expected.x) < 1e-6)
                #expect(abs(p.y - expected.y) < 1e-6)
                #expect(abs(p.z - expected.z) < 1e-6)
            }
        }
    }
}
