import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Curve3D Arc Length

@Suite("Curve3D Arc Length")
struct Curve3DArcLengthTests {
    @Test func totalArcLength() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let len = line.totalArcLength
            #expect(abs(len - 10.0) < 0.01)
        }
    }

    @Test func arcLengthBetween() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let d = line.domain
            let half = line.arcLengthBetween(d.lowerBound, (d.lowerBound + d.upperBound) / 2)
            #expect(abs(half - 5.0) < 0.01)
        }
    }

    @Test func parameterAtLength() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if let line {
            let midParam = line.parameterAtLength(5.0)
            let midPt = line.point(at: midParam)
            #expect(abs(midPt.x - 5.0) < 0.01)
        }
    }

    @Test func parameterAtLengthCircle() {
        let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10)
        if let circle {
            let circumference = circle.totalArcLength
            #expect(abs(circumference - 2 * Double.pi * 10) < 0.1)
            // Quarter arc length should give pi/2 parameter
            let quarterLen = circumference / 4
            let param = circle.parameterAtLength(quarterLen)
            let pt = circle.point(at: param)
            #expect(abs(pt.x) < 0.1)
            #expect(abs(pt.y - 10.0) < 0.1)
        }
    }

    @Test func parameterAtLengthRefusesANonFiniteDistanceOnEveryCurveType() throws {
        // #3034: +infinity answered an infinite parameter on a line, a circle and an ellipse and
        // 0 on a spline; every curve type now fails the same way, with this function's failure
        // value 0 (it has no optional to carry it). 0 is also the start of the line and circle
        // below, so a finite control with a non-zero answer is checked beside each.
        let line = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let ellipse = try #require(
            Curve3D.ellipse(
                center: .zero, normal: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 5))
        let spline = try #require(
            Curve3D.interpolate(points: [
                SIMD3(0, 0, 0), SIMD3(5, 5, 0), SIMD3(10, 0, 0), SIMD3(15, 5, 0),
            ]))
        let curves: [(String, Curve3D)] = [
            ("line", line), ("circle", circle), ("ellipse", ellipse), ("spline", spline),
        ]
        for (name, curve) in curves {
            let finite = curve.parameterAtLength(3)
            #expect(finite > curve.domain.lowerBound, "\(name) control")
            for value in [Double.infinity, -.infinity, .nan] {
                #expect(curve.parameterAtLength(value) == 0, "\(name): distance \(value)")
                #expect(curve.parameterAtLength(5, from: value) == 0, "\(name): start \(value)")
            }
        }
    }
}
