import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Curve Manipulation Tests")
struct BezierCurveManipulationTests {

    @Test func degreeAndPoleCount() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let deg = bez.bezier.degree
            #expect(deg == 3)
            let pc = bez.bezier.poleCount
            #expect(pc == 4)
        }
    }

    @Test func isRational() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            #expect(!bez.bezier.isRational)
        }
    }

    @Test func getPole() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let p = bez.bezier.pole(at: 1)
            #expect(abs(p.x) < 1e-6)
            #expect(abs(p.y) < 1e-6)
        }
    }

    @Test func setPole() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bez.bezier.setPole(at: 2, to: SIMD3(3, 8, 0))
            #expect(ok)
            let p = bez.bezier.pole(at: 2)
            #expect(abs(p.y - 8.0) < 1e-6)
        }
    }

    @Test func segment() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bez.bezier.segment(u1: 0.25, u2: 0.75)
            #expect(ok)
        }
    }

    @Test func increaseDegree() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bez.bezier.increaseDegree(to: 5)
            #expect(ok)
            #expect(bez.bezier.degree == 5)
        }
    }

    @Test func insertPoleAfter() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bez.bezier.insertPoleAfter(index: 2, point: SIMD3(5, 6, 0))
            #expect(ok)
            #expect(bez.bezier.poleCount == 5)
        }
    }

    @Test func removePole() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(5, 6, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bez.bezier.removePole(at: 3)
            #expect(ok)
            #expect(bez.bezier.poleCount == 4)
        }
    }

    @Test func setWeight() {
        if let bez = Curve3D.bezier(poles: [
            SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
        ]) {
            let ok = bez.bezier.setWeight(at: 2, to: 2.0)
            #expect(ok)
            #expect(bez.bezier.isRational)
        }
    }
}
