import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Distance Solution Detail")
struct DistanceSolutionDetailTests {
    @Test func detailBetweenBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 5, height: 5, depth: 5)
        if let box1, let box2 {
            let moved = box2.translated(by: SIMD3(20, 0, 0))
            if let moved {
                let solutions = box1.allDistanceSolutions(to: moved)
                if let solutions, solutions.count > 0 {
                    let detail = box1.distanceSolutionDetail(to: moved, solutionIndex: 0)
                    #expect(detail != nil)
                    if let detail {
                        #expect(detail.supportType1.rawValue >= 0)
                        #expect(detail.supportType2.rawValue >= 0)
                    }
                }
            }
        }
    }

    @Test func detailSupportTypes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 3)
        if let box, let sphere {
            let moved = sphere.translated(by: SIMD3(20, 5, 5))
            if let moved {
                let detail = box.distanceSolutionDetail(to: moved, solutionIndex: 0)
                #expect(detail != nil)
            }
        }
    }
}
