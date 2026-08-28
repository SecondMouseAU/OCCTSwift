import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve-Surface Intersection")
struct CurveSurfaceIntersectTests {
    @Test("Line through sphere produces two points")
    func lineThroughSphere() {
        let line = Curve3D.segment(from: SIMD3(-10, 0, 0), to: SIMD3(10, 0, 0))!
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let results = line.intersections(with: sphere)
        #expect(results.count == 2)
        if results.count == 2 {
            // Points should be at approximately (-5, 0, 0) and (5, 0, 0)
            let xValues = results.map { $0.point.x }.sorted()
            #expect(abs(xValues[0] - (-5.0)) < 0.1)
            #expect(abs(xValues[1] - 5.0) < 0.1)
        }
    }

    @Test("Line tangent to sphere produces one point")
    func lineTangentToSphere() {
        let line = Curve3D.segment(from: SIMD3(-10, 5, 0), to: SIMD3(10, 5, 0))!
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let results = line.intersections(with: sphere)
        // Tangent may produce 1 or 2 very close points
        #expect(results.count >= 1)
    }

    @Test("Line missing sphere produces no points")
    func lineMissingSphere() {
        let line = Curve3D.segment(from: SIMD3(-10, 10, 0), to: SIMD3(10, 10, 0))!
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)!
        let results = line.intersections(with: sphere)
        #expect(results.isEmpty)
    }

    @Test("Line through plane produces one point")
    func lineThroughPlane() {
        let line = Curve3D.segment(from: SIMD3(0, 0, -5), to: SIMD3(0, 0, 5))!
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let results = line.intersections(with: plane)
        #expect(results.count == 1)
        if let first = results.first {
            #expect(abs(first.point.z) < 0.01)
        }
    }
}
