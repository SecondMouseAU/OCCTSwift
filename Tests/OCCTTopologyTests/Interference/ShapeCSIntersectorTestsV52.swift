import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape CSIntersector Tests v52")
struct ShapeCSIntersectorTestsV52 {
    @Test("Intersect line through box")
    func lineIntersectsBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let pts = box.intersectLine(
            origin: SIMD3(-10, 0, 0),
            direction: SIMD3(1, 0, 0))
        #expect(pts.count >= 2)  // enters and exits the box
    }
}
