import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BSpline Curve 2D Manipulation Tests")
struct BSplineCurve2DManipulationTests {

    @Test func knotCount() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let nk = bsp.bspline.knotCount
            #expect(nk > 0)
        }
    }

    @Test func poleCount() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let np = bsp.bspline.poleCount
            #expect(np >= 4)
        }
    }

    @Test func degree() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let deg = bsp.bspline.degree
            #expect(deg >= 1)
        }
    }

    @Test func isRational() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let _ = bsp.bspline.isRational
        }
    }

    @Test func setPole() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let ok = bsp.bspline.setPole(at: 2, to: SIMD2(3, 6))
            #expect(ok)
            let p = bsp.bspline.pole(at: 2)
            #expect(abs(p.y - 6.0) < 1e-6)
        }
    }

    @Test func resolution() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let res = bsp.bspline.resolution(tolerance: 0.001)
            #expect(res > 0)
        }
    }

    @Test func insertKnot() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let d = bsp.domain
            let mid = (d.lowerBound + d.upperBound) / 2.0
            let ok = bsp.bspline.insertKnot(u: mid)
            #expect(ok)
        }
    }

    @Test func segment() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let d = bsp.domain
            let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
            let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
            let ok = bsp.bspline.segment(u1: u1, u2: u2)
            #expect(ok)
        }
    }

    @Test func increaseDegree() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            let oldDeg = bsp.bspline.degree
            let ok = bsp.bspline.increaseDegree(to: oldDeg + 1)
            #expect(ok)
            #expect(bsp.bspline.degree == oldDeg + 1)
        }
    }

    @Test func setWeight() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            // Non-rational BSpline may not accept weights
            let _ = bsp.bspline.setWeight(at: 1, to: 2.0)
        }
    }

    @Test func removeKnot() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
        ]) {
            // Just exercise the API
            let _ = bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0)
        }
    }
}
