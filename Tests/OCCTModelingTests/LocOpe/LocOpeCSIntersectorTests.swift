import Testing

@testable import OCCTSwift

@Suite("LocOpe CSIntersector Tests")
struct LocOpeCSIntersectorTests {
    // #3332: `count >= 2` and `isEmpty` for a line at (5, 5, -5), which runs exactly along the
    // cube's vertical edge (the centred cube spans +-5), the one case where the answer depends on
    // how a line tangent to an edge is counted. The interior line below crosses the cube in two
    // points, the bottom and top faces, at the parameters a line from z = -20 gives: 15 and 25.
    @Test("Line intersects box")
    func lineIntersectsBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let hits = box.intersectLine(origin: SIMD3(2, 3, -20), direction: SIMD3(0, 0, 1))
        #expect(hits.count == 2, "bottom and top faces")
        let ordered = hits.sorted { $0.parameter < $1.parameter }
        guard ordered.count == 2 else { return }
        #expect(abs(ordered[0].parameter - 15) < 1e-6)
        #expect(abs(ordered[1].parameter - 25) < 1e-6)
        #expect(abs(ordered[0].point.x - 2) < 1e-6 && abs(ordered[0].point.y - 3) < 1e-6)
        #expect(abs(ordered[0].point.z + 5) < 1e-6)
        #expect(abs(ordered[1].point.x - 2) < 1e-6 && abs(ordered[1].point.y - 3) < 1e-6)
        #expect(abs(ordered[1].point.z - 5) < 1e-6)

        // The line along the cube's corner edge is reported at its two ends, (5, 5, -5) and
        // (5, 5, 5) (measured).
        let along = box.intersectLine(origin: SIMD3(5, 5, -5), direction: SIMD3(0, 0, 1))
        #expect(along.count == 2)
        let zs = along.map { $0.point.z }.sorted()
        if zs.count == 2 {
            #expect(abs(zs[0] + 5) < 1e-6 && abs(zs[1] - 5) < 1e-6)
        }
    }

    @Test("Line misses box")
    func lineMissesBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let intersections = box.intersectLine(
            origin: SIMD3(100, 100, -5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(intersections.isEmpty, "Line should miss the box")

        // The same direction moved to x = 2, y = 3 hits: the miss is the position, not the call.
        let hit = box.intersectLine(origin: SIMD3(2, 3, -5), direction: SIMD3(0, 0, 1))
        #expect(!hit.isEmpty)
        // A line parallel to a face and just outside it, and one pointing away, miss as well.
        #expect(box.intersectLine(origin: SIMD3(5.5, 0, -20), direction: SIMD3(0, 0, 1)).isEmpty)
        #expect(box.intersectLine(origin: SIMD3(0, 0, 20), direction: SIMD3(1, 0, 0)).isEmpty)
    }

    @Test("Intersection points have valid coordinates")
    func intersectionPointCoordinates() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
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
