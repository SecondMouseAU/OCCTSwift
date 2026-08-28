import Foundation
import Testing
import simd

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
}
