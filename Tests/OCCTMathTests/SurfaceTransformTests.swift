import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Transform")
struct SurfaceTransformTests {

    @Test("Translate surface")
    func translateSurface() {
        guard let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane setup nil")
            return
        }
        let ok = s.translate(dx: 10, dy: 0, dz: 5)
        #expect(ok)
        // Probed (Scripts/repro/766-math-surface-transform): P(1, 1) moves from (1, 1, 0) to (11, 1, 5).
        let p = s.point(atU: 1, v: 1)
        #expect(simd_distance(p, SIMD3<Double>(11, 1, 5)) < 1e-12)
    }

    @Test("Rotate surface")
    func rotateSurface() {
        guard let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane setup nil")
            return
        }
        let ok = s.rotate(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(1, 0, 0),
            angle: .pi / 4)
        #expect(ok)
        // Probed (Scripts/repro/766-math-surface-transform): P(1, 1) turns from (1, 1, 0) to (1, cos 45, sin 45).
        let p = s.point(atU: 1, v: 1)
        #expect(simd_distance(p, SIMD3<Double>(1, 0.70710678118654757, 0.70710678118654746)) < 1e-12)
    }

    @Test("Scale surface")
    func scaleSurface() {
        guard let s = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane setup nil")
            return
        }
        let ok = s.scale(center: SIMD3(0, 0, 0), factor: 2)
        #expect(ok)
        // A plane through the scale centre maps onto itself with the same parametrization, so the
        // plane is lifted to z = 5 for the scale to show. Probed (Scripts/repro/766-math-surface-transform):
        // P(1, 1) goes from (1, 1, 5) to (1, 1, 10): Geom_Plane keeps unit axes and only
        // its location scales.
        let p = s.point(atU: 1, v: 1)
        #expect(simd_distance(p, SIMD3<Double>(1, 1, 10)) < 1e-12)
    }

    @Test("Mirror surface through point")
    func mirrorPointSurface() {
        guard let s = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane setup nil")
            return
        }
        let ok = s.mirrorPoint(SIMD3(0, 0, 0))
        #expect(ok)
        // Probed (Scripts/repro/766-math-surface-transform): P(1, 1) = (1, 1, 5) goes to (-1, -1, -5).
        let p = s.point(atU: 1, v: 1)
        #expect(simd_distance(p, SIMD3<Double>(-1, -1, -5)) < 1e-12)
    }

    @Test("Mirror surface through axis")
    func mirrorAxisSurface() {
        guard let s = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane setup nil")
            return
        }
        let ok = s.mirrorAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        #expect(ok)
        // Probed (Scripts/repro/766-math-surface-transform): P(1, 1) = (1, 1, 5) goes to (1, -1, -5).
        let p = s.point(atU: 1, v: 1)
        #expect(simd_distance(p, SIMD3<Double>(1, -1, -5)) < 1e-12)
    }

    @Test("Mirror surface through plane")
    func mirrorPlaneSurface() {
        guard let s = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1)) else {
            Issue.record("plane setup nil")
            return
        }
        let ok = s.mirrorPlane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(ok)
        // Probed (Scripts/repro/766-math-surface-transform): P(1, 1) = (1, 1, 5) goes to (1, 1, -5).
        let p = s.point(atU: 1, v: 1)
        #expect(simd_distance(p, SIMD3<Double>(1, 1, -5)) < 1e-12)
    }

    @Test("Transform BezierSurface values")
    func transformBezierSurface() {
        // bezierFill down-casts its inputs to Geom_BezierCurve and returns nil for anything else, so
        // the boundaries must be real Bezier curves. This test used to pass Curve3D.line, got nil
        // back, and skipped its whole body via `if let` without ever calling translate (#488).
        guard let c1 = Curve3D.bezier(poles: [SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 0, 0)]),
            let c2 = Curve3D.bezier(poles: [SIMD3(0, 10, 0), SIMD3(5, 10, 3), SIMD3(10, 10, 0)]),
            let s = Surface.bezierFill(c1, c2)
        else {
            Issue.record("bezierFill setup nil")
            return
        }
        let before = s.point(atU: 0.5, v: 0.5)
        #expect(s.translate(dx: 0, dy: 0, dz: 100))
        let after = s.point(atU: 0.5, v: 0.5)
        #expect(abs(after.x - before.x) < 1e-9)
        #expect(abs(after.y - before.y) < 1e-9)
        #expect(abs(after.z - before.z - 100) < 1e-9)
    }
}

