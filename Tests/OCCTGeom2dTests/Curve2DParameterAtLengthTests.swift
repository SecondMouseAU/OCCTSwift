import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #37: Curve2D.parameterAtLength

// #1979: every test nested its assertions in `if let` (a nil length or parameter passed), used
// 0.01 to 0.1 of slack on exact values, and `parameterAtLengthFailure` asserted nothing
// (`_ = result`). Each now requires its values and pins them to GCPnts_AbscissaPoint
// (Scripts/repro/766-geom2d-param-at-length-point2d/).
@Suite("Curve2D parameterAtLength Tests")
struct Curve2DParameterAtLengthTests {

    @Test("Parameter at full arc length of a circle arc")
    func parameterAtFullArcLength() throws {
        // Quarter arc of radius 10 has length pi/2 * 10 ≈ 15.708
        let arc = try #require(
            Curve2D.arcOfCircle(
                center: .zero, radius: 10,
                startAngle: 0, endAngle: .pi / 2))
        let expectedLength = .pi / 2.0 * 10.0
        let totalLen = try #require(arc.length)
        #expect(abs(totalLen - expectedLength) < 1e-9)
        // Parameter at half the arc length is pi/4, the midpoint of the arc.
        let param = try #require(arc.parameterAtLength(totalLen / 2))
        #expect(abs(param - .pi / 4) < 1e-9)
        let pt = arc.point(at: param)
        #expect(abs(pt.x - 7.07106781187) < 1e-9)
        #expect(abs(pt.y - 7.07106781187) < 1e-9)
    }

    @Test("Parameter at zero length returns start parameter")
    func parameterAtZeroLength() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let param = try #require(seg.parameterAtLength(0))
        #expect(abs(param) < 1e-12)
        let pt = seg.point(at: param)
        #expect(abs(pt.x) < 1e-6)
        #expect(abs(pt.y) < 1e-6)
    }

    @Test("Parameter at full length of a segment")
    func parameterAtFullSegmentLength() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let totalLen = try #require(seg.length)
        let param = try #require(seg.parameterAtLength(totalLen))
        let pt = seg.point(at: param)
        #expect(abs(pt.x - 10.0) < 1e-9)
        #expect(abs(pt.y) < 1e-6)
    }

    @Test("Parameter at length from non-start parameter")
    func parameterAtLengthFromMidpoint() throws {
        // 20-unit horizontal segment; measure 5 units starting from parameter at x=5
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0)))
        let midParam = seg.domain.lowerBound + (seg.domain.upperBound - seg.domain.lowerBound) / 2
        let param = try #require(seg.parameterAtLength(5, from: midParam))
        let pt = seg.point(at: param)
        #expect(abs(pt.x - 15.0) < 1e-9)
    }

    @Test("parameterAtLength returns nil on failure")
    func parameterAtLengthFailure() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        // A trimmed line is not a failure case past its end: GCPnts_AbscissaPoint extrapolates
        // along the basis line and returns u = 1000, and so does the bridge. What does fail is
        // a non-finite length, which reports nil rather than a parameter.
        #expect(seg.parameterAtLength(1000) == 1000)
        #expect(seg.parameterAtLength(.nan) == nil)
    }

    @Test("Trim curve to exact arc length using parameterAtLength")
    func trimToArcLength() throws {
        // Create a 20-unit segment, trim to exactly 7 units from start
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0)))
        let first = seg.domain.lowerBound
        let endParam = try #require(seg.parameterAtLength(7, from: first))
        let trimmed = try #require(seg.trimmed(from: first, to: endParam))
        let len = try #require(trimmed.length)
        #expect(abs(len - 7.0) < 1e-9)
    }
}
