import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Shape Proximity Tests (v0.18.0)

@Suite("Shape Proximity Tests")
struct ShapeProximityTests {

    @Test("Two boxes with small gap detect proximity")
    func twoBoxesProximity() {
        // box1 centered at origin: -5..5 on each axis
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        // box2 corner at (5.05, -5, -5) → gap of 0.05 from box1's +X face
        let box2 = Shape.box(origin: SIMD3(5.05, -5, -5), width: 10, height: 10, depth: 10)!

        let pairs = box1.proximityFaces(with: box2, tolerance: 1.0)
        // BRepExtrema_ShapeProximity should detect the close face pair
        #expect(pairs.count >= 1)  // Gap of 0.05 within tolerance 1.0 should detect proximity

        // Verify the gap distance is correct
        let dist = box1.distance(to: box2)
        #expect(dist != nil)
        if let d = dist {
            #expect(abs(d.distance - 0.05) < 0.01)
        }
    }

    @Test("Two distant shapes have no proximity")
    func distantShapesNoProximity() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(100, 100, 100), width: 10, height: 10, depth: 10)!

        let pairs = box1.proximityFaces(with: box2, tolerance: 0.5)
        #expect(pairs.isEmpty)
    }

    // Deliberately exercises the deprecated `selfIntersects` (#1088); the annotation silences the
    // warning that would otherwise fire on every build.
    @available(*, deprecated)
    @Test("Box does not self-intersect")
    func boxNoSelfIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(!box.selfIntersects)
    }
}
