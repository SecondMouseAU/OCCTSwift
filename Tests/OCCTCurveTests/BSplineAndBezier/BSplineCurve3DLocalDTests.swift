import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.129.0: BSplineCurve LocalD, BSplineSurface completions, BezierSurface completions

@Suite("BSplineCurve3D LocalD v129")
struct BSplineCurve3DLocalDTests {

    @Test("LocalD0 matches LocalValue")
    func localD0() {
        // Create a BSpline curve via interpolation
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0),
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let val = curve.bsplineLocalValue(u: 0.5, fromKnot: k, toKnot: k + 1)
            let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(val.x - d0.x) < 1e-10)
            #expect(abs(val.y - d0.y) < 1e-10)
            #expect(abs(val.z - d0.z) < 1e-10)
        }
    }

    @Test("LocalD1 returns point + tangent")
    func localD1() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0),
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
            let mag = sqrt(
                result.d1.x * result.d1.x + result.d1.y * result.d1.y + result.d1.z * result.d1.z)
            #expect(mag > 0.01)  // tangent should be non-zero
        }
    }

    @Test("LocalD2 returns curvature information")
    func localD2() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0),
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let result = curve.bsplineLocalD2(u: 0.5, fromKnot: k, toKnot: k + 1)
            // Point should match D0
            let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(result.point.x - d0.x) < 1e-10)
            #expect(abs(result.point.y - d0.y) < 1e-10)
        }
    }

    @Test("LocalD3 returns all derivatives")
    func localD3() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0),
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let result = curve.bsplineLocalD3(u: 0.5, fromKnot: k, toKnot: k + 1)
            // Point should match D0
            let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(result.point.x - d0.x) < 1e-10)
            // D1 should match
            let d1result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(result.d1.x - d1result.d1.x) < 1e-10)
        }
    }

    @Test("LocalDN matches D1 for n=1")
    func localDN() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0),
        ]
        if let curve = Curve3D.interpolate(points: points) {
            let k = curve.bsplineLocateU(0.5)
            let dn1 = curve.bsplineLocalDN(u: 0.5, fromKnot: k, toKnot: k + 1, n: 1)
            let d1result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
            #expect(abs(dn1.x - d1result.d1.x) < 1e-10)
            #expect(abs(dn1.y - d1result.d1.y) < 1e-10)
            #expect(abs(dn1.z - d1result.d1.z) < 1e-10)
        }
    }
}
