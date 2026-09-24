import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna ConeSphere Tests")
struct IntAnaConeSphereTests {

    // #1918: this asserted `count >= 0`, which the Swift wrapper already guarantees for any non-nil
    // result (it maps every negative bridge code to nil), so a bridge that always answered 0 passed.
    // Both fixtures' curve counts are measured against IntAna_IntQuadQuad in
    // Scripts/repro/766-intana-cone-sphere/transcript.txt.
    @Test func coneSphereIntersection() {
        // On the axis, the sphere sits clear of the cone: its centre is 5 sin(pi/4) = 3.54 from the
        // cone's surface and its radius is 3.
        let clear = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(0, 0, 5), sphereRadius: 3)
        #expect(clear == 0)
        // Off the axis, the cone pierces the sphere, entering and leaving: two curves.
        let pierced = QuadricIntersection.coneSphere(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: SIMD3(3, 0, 5), sphereRadius: 2)
        #expect(pierced == 2)
    }

    // #1919: this was gated on `count > 0` for a fixture whose count is 0 (see the note on
    // singleSampleIsNotNaN below), so its body never ran, and the body's `pts.count >= 0` could not
    // fail if it had. It now samples the off-axis fixture, which has curves, and checks that every
    // sample lies on both surfaces.
    @Test func coneSphereSamplePoints() {
        let center = SIMD3<Double>(3, 0, 5)
        let radius = 2.0
        let pts = QuadricIntersection.coneSpherePoints(
            semiAngle: .pi / 4, refRadius: 0,
            sphereCenter: center, sphereRadius: radius,
            curveIndex: 1, sampleCount: 10)
        #expect(pts.count == 10)
        for p in pts {
            // On the cone (apex at the origin, semi-angle pi/4): the distance from the Z axis is z.
            #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - p.z) < 1e-9)
            // On the sphere.
            #expect(abs(simd_length(p - center) - radius) < 1e-9)
        }
        // The samples span the curve's whole domain: the first is its start, measured at
        // (3.545, -1.560, 3.873), and the last its end, the mirror image across y = 0.
        if let first = pts.first, let last = pts.last {
            #expect(simd_length(first - SIMD3(3.545027756, -1.559736583, 3.872983346)) < 1e-6)
            #expect(simd_length(last - SIMD3(3.545027756, 1.559736583, 3.872983346)) < 1e-6)
        }
    }

    // #1495: `t = first + (last - first) * i / (actual - 1)` divides by zero when `nbSamples ==
    // 1`, producing NaN while still reporting success. `Sampling.requested(_:atLeast:)` is
    // called with `atLeast: 1` from `coneSpherePoints`, which documents `sampleCount: 1` as
    // legal, so the fix is to special-case it (single sample at the curve's domain start), not
    // reject it, matching `OCCTEdgeGetPoints`'s identical `(count == 1) ? first : ...` guard.
    //
    // The fixture matters: a sphere centered ON the cone's axis (`SIMD3(0, 0, 5)`, radius 3) is
    // reported as `curveCount == 0` (measured directly against `IntAna_IntQuadQuad`, not assumed),
    // so `coneSpherePoints` never even reaches the division and a test built on it would pass
    // vacuously either way. An off-axis sphere center makes the cone genuinely pierce the sphere
    // (`curveCount == 2`), which is why the two tests above use it too (#1918, #1919).
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
