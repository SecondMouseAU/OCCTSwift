import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
// Before #766 both tests asserted `count > 0`; the kernel's counts are pinned instead.
@Suite("ShapeAnalysis Curve GetSamplePoints Tests")
struct CurveSamplePointsTests {
    @Test("Sample points on circle")
    func sampleCircle() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let dom = circle.domain
        let points = circle.samplePoints(first: dom.lowerBound, last: dom.upperBound)
        #expect(points.count == 360)
        #expect(points.allSatisfy { abs(simd_length($0) - 5.0) < 1e-9 })
        let first = try #require(points.first)
        let last = try #require(points.last)
        #expect(simd_distance(first, SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_distance(last, SIMD3(5, 0, 0)) < 1e-9)
    }

    @Test("Sample points on line segment")
    func sampleLine() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let dom = seg.domain
        let points = seg.samplePoints(first: dom.lowerBound, last: dom.upperBound)
        // A line needs only its end points.
        #expect(points == [SIMD3(0, 0, 0), SIMD3(10, 0, 0)])
    }
}
