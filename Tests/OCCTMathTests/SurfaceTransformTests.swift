import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Transform")
struct SurfaceTransformTests {

    @Test("Translate surface")
    func translateSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.translate(dx: 10, dy: 0, dz: 5)
            #expect(ok)
        }
    }

    @Test("Rotate surface")
    func rotateSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.rotate(
                axisOrigin: SIMD3(0, 0, 0),
                axisDirection: SIMD3(1, 0, 0),
                angle: .pi / 4)
            #expect(ok)
        }
    }

    @Test("Scale surface")
    func scaleSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.scale(center: SIMD3(0, 0, 0), factor: 2)
            #expect(ok)
        }
    }

    @Test("Mirror surface through point")
    func mirrorPointSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.mirrorPoint(SIMD3(0, 0, 0))
            #expect(ok)
        }
    }

    @Test("Mirror surface through axis")
    func mirrorAxisSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.mirrorAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
            #expect(ok)
        }
    }

    @Test("Mirror surface through plane")
    func mirrorPlaneSurface() {
        let surf = Surface.plane(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if let s = surf {
            let ok = s.mirrorPlane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
            #expect(ok)
        }
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

