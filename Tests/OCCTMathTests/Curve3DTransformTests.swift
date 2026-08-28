import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Transform")
struct Curve3DTransformTests {

    @Test("Translate BSpline curve")
    func translateCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0),
        ])
        if let c = curve {
            let p0 = c.point(at: 0)
            let ok = c.translate(dx: 10, dy: 0, dz: 0)
            #expect(ok)
            let p1 = c.point(at: 0)
            #expect(abs(p1.x - p0.x - 10) < 0.001)
        }
    }

    @Test("Rotate curve")
    func rotateCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0),
        ])
        if let c = curve {
            let ok = c.rotate(
                axisOrigin: SIMD3(0, 0, 0),
                axisDirection: SIMD3(0, 0, 1),
                angle: .pi / 2)
            #expect(ok)
            let p = c.point(at: 0)
            // After 90 degree rotation around Z, (1,0,0) -> (0,1,0)
            #expect(abs(p.x) < 0.1)
            #expect(abs(p.y - 1) < 0.1)
        }
    }

    @Test("Scale curve")
    func scaleCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0),
        ])
        if let c = curve {
            let ok = c.scale(center: SIMD3(0, 0, 0), factor: 2)
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.x - 2) < 0.1)
        }
    }

    @Test("Mirror curve through point")
    func mirrorPointCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0),
        ])
        if let c = curve {
            let ok = c.mirrorPoint(SIMD3(0, 0, 0))
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.x + 1) < 0.1)  // (1,0,0) -> (-1,0,0)
        }
    }

    @Test("Mirror curve through axis")
    func mirrorAxisCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 1, 0),
        ])
        if let c = curve {
            let ok = c.mirrorAxis(origin: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.y + 1) < 0.1)  // y=1 -> y=-1
        }
    }

    @Test("Mirror curve through plane")
    func mirrorPlaneCurve() {
        let curve = Curve3D.interpolate(points: [
            SIMD3(1, 0, 5), SIMD3(2, 0, 5), SIMD3(3, 0, 5),
        ])
        if let c = curve {
            let ok = c.mirrorPlane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
            #expect(ok)
            let p = c.point(at: 0)
            #expect(abs(p.z + 5) < 0.1)  // z=5 -> z=-5
        }
    }
}

