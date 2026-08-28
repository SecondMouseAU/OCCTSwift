import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtSS Tests")
struct ExtremaExtSSTests {
    @Test func parallelPlanes() {
        if let p1 = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let p2 = Surface.plane(origin: SIMD3(0, 0, 7), normal: SIMD3(0, 0, 1))
        {
            let result = p1.extremaSS(other: p2)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }

    @Test func sphereDistance() {
        if let s1 = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3.0),
            let s2 = Surface.sphere(center: SIMD3(10, 0, 0), radius: 2.0)
        {
            let result = s1.extremaSS(other: s2)
            #expect(result.isDone)
            // Two spheres, non-parallel
            if !result.isParallel && result.count >= 1 {
                let pp = s1.extremaSSPoint(other: s2, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(abs(dist - 5.0) < 0.5)  // 10 - 3 - 2 = 5
            }
        }
    }
}
