import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `Shape.box(width: 10, ...)` is centred, so the box spans -5...5 on every axis.
///
/// Every test here asserted only `result != nil` (or `distance > 0`) inside `if let`, so a
/// fixture that failed to build passed silently and any distance at all was accepted (#1891 to
/// #1894). Each is now unconditional and pinned to the value measured in
/// Scripts/repro/766-shape-distance-overload-tests/transcript.txt.
@Suite("Shape distance to Wire/Edge/Face") struct ShapeDistanceOverloadTests {
    @Test("Shape distance to Wire")
    func distanceToWire() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let wire = Wire.circle(origin: SIMD3(20, 0, 0), radius: 1)
        else {
            Issue.record("fixture construction failed")
            return
        }
        guard let result = box.distance(to: wire) else {
            Issue.record("distance(to: Wire) returned nil")
            return
        }
        // The r = 1 circle in z = 0 around (20, 0, 0) comes nearest the x = 5 face at (19, 0, 0).
        #expect(
            abs(result.distance - 14) < 1e-9, "expected 20 - 1 - 5 = 14, got \(result.distance)")
        #expect(simd_distance(result.pointOnShape1, SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_distance(result.pointOnShape2, SIMD3(19, 0, 0)) < 1e-9)
    }

    @Test("Shape intersects Wire")
    func intersectsWire() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let far = Wire.circle(origin: SIMD3(20, 0, 0), radius: 1),
            let inside = Wire.circle(origin: .zero, radius: 1)
        else {
            Issue.record("fixture construction failed")
            return
        }
        #expect(!box.intersects(far), "a circle 14 units from the box does not touch it")
        // The positive case, which is what makes the negative one mean something: a bridge that
        // always answered false would otherwise pass. The r = 1 circle at the origin lies inside
        // the solid, and BRepExtrema_DistShapeShape measures a solid's interior as distance 0.
        #expect(box.intersects(inside), "a circle inside the solid box intersects it")
    }

    @Test("Shape distance to Edge")
    func distanceToEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let edges = box.edges()
        #expect(edges.count == 12)
        guard let edge = edges.first else {
            Issue.record("a box has edges")
            return
        }
        guard let result = box.distance(to: edge) else {
            Issue.record("distance(to: Edge) returned nil")
            return
        }
        // The box's own edge lies on it: distance 0, and the reported points coincide on it.
        #expect(
            abs(result.distance) < 1e-9,
            "a shape's own edge is at distance 0, got \(result.distance)")
        #expect(simd_distance(result.pointOnShape1, result.pointOnShape2) < 1e-9)
    }

    @Test("Shape distance to Face")
    func distanceToFace() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(width: 5, height: 5, depth: 5)
        else {
            Issue.record("fixture construction failed")
            return
        }
        guard let face = box2.faces().first else {
            Issue.record("a box has faces")
            return
        }
        guard let result = box1.distance(to: face) else {
            Issue.record("distance(to: Face) returned nil")
            return
        }
        // box2's faces sit inside box1 (±2.5 within ±5); the solid's interior is distance 0.
        #expect(
            abs(result.distance) < 1e-9,
            "a face inside the solid is at distance 0, got \(result.distance)")
        // And the reported point is on that face, the x = -2.5 cap: faces()[0] of a centred box.
        #expect(
            abs(result.pointOnShape2.x - (-2.5)) < 1e-9,
            "point on the face, got \(result.pointOnShape2)")
    }
}
