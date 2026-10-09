import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe CSIntersector Tests")
struct LocOpeCSIntersectorTests {
    @Test("Line intersects box")
    func lineIntersectsBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let intersections = box.intersectLine(
            origin: SIMD3(5, 5, -5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(intersections.count >= 2, "Line should intersect box in at least 2 points")
    }

    @Test("Line misses box")
    func lineMissesBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let intersections = box.intersectLine(
            origin: SIMD3(100, 100, -5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(intersections.isEmpty, "Line should miss the box")
    }

    @Test("Intersection points have valid coordinates")
    func intersectionPointCoordinates() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let intersections = box.intersectLine(
            origin: SIMD3(5, 5, -5),
            direction: SIMD3(0, 0, 1)
        )
        if let first = intersections.first {
            #expect(abs(first.point.x - 5) < 1, "X should be near 5")
            #expect(abs(first.point.y - 5) < 1, "Y should be near 5")
        }
    }
}
