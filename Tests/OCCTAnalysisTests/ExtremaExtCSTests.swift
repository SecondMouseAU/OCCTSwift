import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtCS Tests")
struct ExtremaExtCSTests {
    @Test func curveSurfaceParallel() {
        // Line parallel to plane
        if let line = Curve3D.line(through: SIMD3(0, 0, 10), direction: SIMD3(1, 0, 0)),
            let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        {
            let result = line.extremaCS(range: -10...10, surface: plane)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }

    @Test func curveSurfaceDistance() {
        // Line near a sphere
        if let line = Curve3D.line(through: SIMD3(10, 0, 0), direction: SIMD3(0, 0, 1)),
            let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)
        {
            let result = line.extremaCS(range: -5...5, surface: sphere)
            #expect(result.isDone)
            if !result.isParallel && result.count >= 1 {
                let pp = line.extremaCSPoint(range: -5...5, surface: sphere, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(dist > 4.0)  // At least 5 away from surface
            }
        }
    }
}
