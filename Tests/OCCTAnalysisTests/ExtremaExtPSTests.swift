import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPS Tests")
struct ExtremaExtPSTests {
    @Test func pointSurfaceDistance() {
        // Point above sphere
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0) {
            let result = sphere.extremaPS(point: SIMD3(0, 0, 10))
            #expect(result.isDone)
            #expect(result.count >= 1)
            if result.count >= 1 {
                // Find minimum distance
                var minDist = Double.infinity
                for i in 1...result.count {
                    let ps = sphere.extremaPSPoint(point: SIMD3(0, 0, 10), index: i)
                    let d = ps.squareDistance.squareRoot()
                    if d < minDist { minDist = d }
                }
                #expect(abs(minDist - 5.0) < 0.1)
            }
        }
    }

    @Test func pointOnSurfaceParams() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0) {
            let result = sphere.extremaPS(point: SIMD3(0, 0, 10))
            if result.isDone && result.count >= 1 {
                let ps = sphere.extremaPSPoint(point: SIMD3(0, 0, 10), index: 1)
                // Point should be on the sphere surface
                let px = ps.point.x
                let py = ps.point.y
                let pz = ps.point.z
                let r = (px * px + py * py + pz * pz).squareRoot()
                #expect(abs(r - 5.0) < 0.1)
            }
        }
    }
}
