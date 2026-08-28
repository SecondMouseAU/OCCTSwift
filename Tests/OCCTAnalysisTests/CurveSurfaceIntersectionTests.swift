import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve-Surface Intersection")
struct CurveSurfaceIntersectionTests {
    @Test("Line intersects sphere")
    func lineIntersectsSphere() {
        let line = Curve3D.segment(from: SIMD3(0, 0, -20), to: SIMD3(0, 0, 20))!
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let hits = line.intersections(with: sphere)
        #expect(hits.count == 2)
        if hits.count == 2 {
            // Intersection points should be at z=±5
            let zValues = hits.map { abs($0.point.z) }.sorted()
            #expect(abs(zValues[0] - 5.0) < 0.1)
            #expect(abs(zValues[1] - 5.0) < 0.1)
        }
    }

    @Test("Line parallel to plane doesn't intersect")
    func lineParallelToPlane() {
        let line = Curve3D.segment(from: SIMD3(0, 0, 5), to: SIMD3(10, 0, 5))!
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let hits = line.intersections(with: plane)
        #expect(hits.count == 0)
    }
}
