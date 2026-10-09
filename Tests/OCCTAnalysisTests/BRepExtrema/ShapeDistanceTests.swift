import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - ShapeDistance")
struct ShapeDistanceTests {

    @Test func boxSphereDistance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let sphere = Shape.sphere(radius: 3)
            if let sph = sphere {
                // Move sphere away by translating
                if let moved = sph.translated(by: SIMD3(20, 5, 5)) {
                    if let dist = ShapeDistance(shape1: box, shape2: moved) {
                        #expect(dist.isDone)
                        #expect(dist.value > 0)
                        #expect(dist.solutionCount >= 1)
                        if dist.solutionCount > 0 {
                            let p1 = dist.pointOnShape1(at: 0)
                            let p2 = dist.pointOnShape2(at: 0)
                            #expect(p1.x > 0)
                            #expect(p2.x > 0)
                            if let t1 = dist.supportType1(at: 0) {
                                #expect(t1.rawValue >= 0 && t1.rawValue <= 2)
                            }
                            let s1 = dist.supportShape1(at: 0)
                            #expect(s1 != nil)
                        }
                    }
                }
            }
        }
    }
}
