import Foundation
import Testing
import simd

@testable import OCCTSwift

// #416: no existing test asserted that Curve3D's immutable transform family
// (translated/rotated/scaled/mirrored) and its mutating counterpart
// (translate/rotate/scale/mirrorPoint/mirrorAxis/mirrorPlane) produce identical
// geometry for identical input, despite sharing the same underlying gp_Trsf
// construction. For each pair: take one immutable copy BEFORE mutating the
// original in place, apply the same transform to both, then compare.

@Suite("Curve3D Transform Family Parity")
struct Curve3DTransformFamilyParityTests {

    private func points(on curve: Curve3D, count: Int = 5) -> [SIMD3<Double>] {
        let d = curve.domain
        return (0..<count).map { i in
            let t = d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / Double(count - 1)
            return curve.point(at: t)
        }
    }

    private func assertMatch(_ a: Curve3D, _ b: Curve3D, tolerance: Double = 1e-9) {
        let pa = points(on: a)
        let pb = points(on: b)
        #expect(pa.count == pb.count)
        for (p, q) in zip(pa, pb) {
            #expect(abs(p.x - q.x) < tolerance)
            #expect(abs(p.y - q.y) < tolerance)
            #expect(abs(p.z - q.z) < tolerance)
        }
    }

    @Test("translate vs translated")
    func translateParity() {
        let base = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let copy = base.translated(by: SIMD3(3, -2, 1.5))
        let ok = base.translate(dx: 3, dy: -2, dz: 1.5)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("rotate vs rotated")
    func rotateParity() {
        let base = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(10, 0, 0))!
        let axisOrigin = SIMD3<Double>(0, 0, 0)
        let axisDirection = SIMD3<Double>(0, 0, 1)
        let angle = Double.pi / 3
        let copy = base.rotated(around: axisOrigin, direction: axisDirection, angle: angle)
        let ok = base.rotate(axisOrigin: axisOrigin, axisDirection: axisDirection, angle: angle)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("scale vs scaled")
    func scaleParity() {
        let base = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 0, 0))!
        let center = SIMD3<Double>(0, 0, 0)
        let copy = base.scaled(from: center, factor: 2.5)
        let ok = base.scale(center: center, factor: 2.5)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("mirrorPoint vs mirrored(acrossPoint:)")
    func mirrorPointParity() {
        let base = Curve3D.segment(from: SIMD3(1, 2, 3), to: SIMD3(4, 5, 6))!
        let point = SIMD3<Double>(1, 1, 1)
        let copy = base.mirrored(acrossPoint: point)
        let ok = base.mirrorPoint(point)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("mirrorAxis vs mirrored(acrossAxis:direction:)")
    func mirrorAxisParity() {
        let base = Curve3D.segment(from: SIMD3(1, 1, 0), to: SIMD3(2, 1, 0))!
        let origin = SIMD3<Double>(0, 0, 0)
        let direction = SIMD3<Double>(1, 0, 0)
        let copy = base.mirrored(acrossAxis: origin, direction: direction)
        let ok = base.mirrorAxis(origin: origin, direction: direction)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }

    @Test("mirrorPlane vs mirrored(acrossPlane:normal:)")
    func mirrorPlaneParity() {
        let base = Curve3D.segment(from: SIMD3(1, 0, 5), to: SIMD3(2, 0, 5))!
        let origin = SIMD3<Double>(0, 0, 0)
        let normal = SIMD3<Double>(0, 0, 1)
        let copy = base.mirrored(acrossPlane: origin, normal: normal)
        let ok = base.mirrorPlane(origin: origin, normal: normal)
        #expect(ok)
        #expect(copy != nil)
        if let copy = copy {
            assertMatch(base, copy)
        }
    }
}
