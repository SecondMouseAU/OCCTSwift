import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis Curve GetSamplePoints Tests")
struct CurveSamplePointsTests {
    @Test("Sample points on circle")
    func sampleCircle() throws {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let dom = circle.domain
        let points = circle.samplePoints(first: dom.lowerBound, last: dom.upperBound)
        #expect(points.count > 0)
        // First point should be on the circle at radius 5
        if let p = points.first {
            let distFromOrigin = simd_length(p)
            #expect(abs(distFromOrigin - 5.0) < 0.1)
        }
    }

    @Test("Sample points on line segment")
    func sampleLine() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let dom = seg.domain
        let points = seg.samplePoints(first: dom.lowerBound, last: dom.upperBound)
        #expect(points.count > 0)
    }
}
