import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.40.0: Extended Distance

@Suite("Extended Distance Solutions")
struct ExtendedDistanceTests {
    @Test("Multiple distance solutions between spheres")
    func sphereDistanceSolutions() {
        let sphere1 = Shape.sphere(radius: 5)!
        let sphere2 = Shape.sphere(radius: 5)!.translated(by: SIMD3(20, 0, 0))!
        let solutions = sphere1.allDistanceSolutions(to: sphere2)
        #expect(solutions != nil)
        if let solutions {
            #expect(solutions.count >= 1)
            // Minimum distance should be 10 (20 - 5 - 5)
            #expect(abs(solutions[0].distance - 10) < 0.1)
        }
    }

    @Test("Box distance solutions")
    func boxDistanceSolutions() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(20, 0, 0))!
        let solutions = box1.allDistanceSolutions(to: box2)
        #expect(solutions != nil)
        if let solutions {
            #expect(solutions.count >= 1)
            // Distance between boxes: 20 - 5 - 5 = 10
            #expect(abs(solutions[0].distance - 10) < 0.1)
        }
    }

    @Test("Inner distance detection, non-overlapping shapes")
    func notInner() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(20, 0, 0))!
        let isInner = box1.isInside(box2)
        #expect(isInner == false)
    }
}
