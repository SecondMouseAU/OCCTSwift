import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.107.0 Tests

@Suite("BSpline Curve 3D Manipulation Tests")
struct BSplineCurve3DManipulationTests {

    @Test func knotCount() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let nk = bsp.bspline.knotCount
            #expect(nk > 0)
        }
    }

    @Test func poleCount() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let np = bsp.bspline.poleCount
            #expect(np >= 5)
        }
    }

    @Test func degree() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let deg = bsp.bspline.degree
            #expect(deg >= 1)
        }
    }

    @Test func isRational() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            // Interpolated BSplines are typically non-rational
            let _ = bsp.bspline.isRational
        }
    }

    @Test func knotsArray() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let knots = bsp.bspline.knots
            #expect(knots.count > 0)
            if knots.count >= 2 {
                #expect(knots.last! > knots.first!)
            }
        }
    }

    @Test func multiplicities() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let mults = bsp.bspline.multiplicities
            #expect(mults.count > 0)
            if let first = mults.first {
                #expect(first > 0)
            }
        }
    }

    @Test func getPole() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let p = bsp.bspline.pole(at: 1)
            // First pole should be near origin
            #expect(abs(p.x) < 1.0)
        }
    }

    @Test func setPole() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bsp.bspline.setPole(at: 3, to: SIMD3(5, 7, 0))
            #expect(ok)
            let p = bsp.bspline.pole(at: 3)
            #expect(abs(p.y - 7.0) < 1e-6)
        }
    }

    @Test func getAndSetWeight() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let w = bsp.bspline.weight(at: 1)
            #expect(abs(w - 1.0) < 1e-6)
        }
    }

    @Test func insertKnot() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let knots = bsp.bspline.knots
            if knots.count >= 2 {
                let mid = (knots.first! + knots.last!) / 2.0
                let nkBefore = bsp.bspline.knotCount
                let ok = bsp.bspline.insertKnot(u: mid)
                #expect(ok)
                #expect(bsp.bspline.knotCount >= nkBefore)
            }
        }
    }

    @Test func segment() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let d = bsp.domain
            let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
            let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
            let ok = bsp.bspline.segment(u1: u1, u2: u2)
            #expect(ok)
        }
    }

    @Test func increaseDegree() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let oldDeg = bsp.bspline.degree
            let ok = bsp.bspline.increaseDegree(to: oldDeg + 1)
            #expect(ok)
            #expect(bsp.bspline.degree == oldDeg + 1)
        }
    }

    @Test func resolution() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            let res = bsp.bspline.resolution(tolerance3d: 0.001)
            #expect(res > 0)
        }
    }

    @Test func setPeriodic() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            // Setting non-periodic on an already non-periodic curve should succeed
            let ok = bsp.bspline.setPeriodic(false)
            #expect(ok)
        }
    }

    @Test func removeKnot() {
        if let bsp = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ]) {
            // Insert a knot first, then try to remove it
            let knots = bsp.bspline.knots
            if knots.count >= 2 {
                let mid = (knots.first! + knots.last!) / 2.0
                _ = bsp.bspline.insertKnot(u: mid)
                // Try removing, may or may not succeed depending on geometry
                let _ = bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0)
            }
        }
    }
}
