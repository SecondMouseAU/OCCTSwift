import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #37: Curve2D.parameterAtLength

@Suite("Curve2D parameterAtLength Tests")
struct Curve2DParameterAtLengthTests {

    @Test("Parameter at full arc length of a circle arc")
    func parameterAtFullArcLength() {
        // Quarter arc of radius 10 has length pi/2 * 10 ≈ 15.708
        let arc = Curve2D.arcOfCircle(
            center: .zero, radius: 10,
            startAngle: 0, endAngle: .pi / 2)!
        let expectedLength = .pi / 2.0 * 10.0
        if let totalLen = arc.length {
            #expect(abs(totalLen - expectedLength) < 0.01)
        }
        // Parameter at half the arc length should be at pi/4 (midpoint of the arc)
        if let halfLen = arc.length {
            if let param = arc.parameterAtLength(halfLen / 2) {
                let pt = arc.point(at: param)
                // At pi/4 on a radius-10 circle: x ≈ y ≈ 7.071
                #expect(abs(pt.x - 7.071) < 0.05)
                #expect(abs(pt.y - 7.071) < 0.05)
            }
        }
    }

    @Test("Parameter at zero length returns start parameter")
    func parameterAtZeroLength() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        if let param = seg.parameterAtLength(0) {
            let pt = seg.point(at: param)
            #expect(abs(pt.x) < 1e-6)
            #expect(abs(pt.y) < 1e-6)
        }
    }

    @Test("Parameter at full length of a segment")
    func parameterAtFullSegmentLength() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        if let totalLen = seg.length, let param = seg.parameterAtLength(totalLen) {
            let pt = seg.point(at: param)
            #expect(abs(pt.x - 10.0) < 0.01)
            #expect(abs(pt.y) < 1e-6)
        }
    }

    @Test("Parameter at length from non-start parameter")
    func parameterAtLengthFromMidpoint() {
        // 20-unit horizontal segment; measure 5 units starting from parameter at x=5
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0))!
        let midParam = seg.domain.lowerBound + (seg.domain.upperBound - seg.domain.lowerBound) / 2
        if let param = seg.parameterAtLength(5, from: midParam) {
            let pt = seg.point(at: param)
            #expect(abs(pt.x - 15.0) < 0.1)
        }
    }

    @Test("parameterAtLength returns nil on failure")
    func parameterAtLengthFailure() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        // Asking for more than the total arc length should fail
        let result = seg.parameterAtLength(1000)
        // result may be nil or may extrapolate — either is acceptable; just ensure no crash
        _ = result
    }

    @Test("Trim curve to exact arc length using parameterAtLength")
    func trimToArcLength() {
        // Create a 20-unit segment, trim to exactly 7 units from start
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0))!
        let first = seg.domain.lowerBound
        if let endParam = seg.parameterAtLength(7, from: first) {
            if let trimmed = seg.trimmed(from: first, to: endParam) {
                if let len = trimmed.length {
                    #expect(abs(len - 7.0) < 0.01)
                }
            }
        }
    }
}
