import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shape CSIntersector Tests v52")
struct ShapeCSIntersectorTestsV52 {
    @Test("Intersect line through box")
    func lineIntersectsBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let pts = box.intersectLine(
            origin: SIMD3(-10, 0, 0),
            direction: SIMD3(1, 0, 0))
        // Enters through the x = -5 wall and leaves through x = +5: two hits, at line parameters
        // 5 and 15 (the direction is a unit vector).
        #expect(pts.count == 2)
        let ordered = pts.sorted { $0.parameter < $1.parameter }
        if ordered.count == 2 {
            #expect(vectorDistance(ordered[0].point, SIMD3(-5, 0, 0)) < 1e-9)
            #expect(vectorDistance(ordered[1].point, SIMD3(5, 0, 0)) < 1e-9)
            #expect(abs(ordered[0].parameter - 5) < 1e-9)
            #expect(abs(ordered[1].parameter - 15) < 1e-9)
        }

        // Control: the same direction one box-width above the box hits nothing.
        let miss = box.intersectLine(origin: SIMD3(-10, 20, 0), direction: SIMD3(1, 0, 0))
        #expect(miss.isEmpty)
    }
}
