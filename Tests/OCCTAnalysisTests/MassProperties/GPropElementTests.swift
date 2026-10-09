import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GProp Element Properties Tests")
struct GPropElementTests {

    @Test func lineSegmentLength() {
        let result = GeometryProperties.lineSegment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(abs((result?.length ?? 0) - 10.0) < 1e-4)
        #expect(abs((result?.center.x ?? 0) - 5.0) < 1e-4)
    }

    @Test func circularArcLength() {
        let result = GeometryProperties.circularArc(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 1.0, u1: 0, u2: .pi)
        #expect(abs((result?.arcLength ?? 0) - Double.pi) < 1e-4)
    }

    @Test func pointSetCentroid() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
        ]
        let result = GeometryProperties.pointSetCentroid(points)
        #expect(abs(result.count - 4.0) < 1e-4)
        if let c = result.centroid {
            #expect(abs(c.x - 5.0) < 1e-4)
            #expect(abs(c.y - 5.0) < 1e-4)
        } else {
            Issue.record("a four-point set has a centroid")
        }
    }

    @Test func sphereSurfaceArea() {
        let area = GeometryProperties.sphereSurfaceArea(radius: 5.0)
        let expected = 4.0 * Double.pi * 25.0
        #expect(abs(area - expected) < 0.1)
    }

    @Test func sphereVolume() {
        let vol = GeometryProperties.sphereVolume(radius: 5.0)
        let expected = (4.0 / 3.0) * Double.pi * 125.0
        #expect(abs(vol - expected) < 0.5)
    }
}
