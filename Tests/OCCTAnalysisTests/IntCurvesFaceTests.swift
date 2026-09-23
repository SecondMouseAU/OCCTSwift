import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntCurvesFace Intersection")
struct IntCurvesFaceTests {
    /// `Shape.box` is centred, so a 10x20x30 box spans x -5...5, y -10...10, z -15...15
    /// and `faces()` comes back in a fixed order: [0] and [1] are the x caps, [2] and [3]
    /// the y caps, [4] and [5] the z caps.
    ///
    /// The version of this test before #2199 intersected `faces()[0]`, the x = -5 plane,
    /// with a ray along +Z. A ray cannot cross a plane it runs parallel to, so the call
    /// correctly returned nothing, and the test asserted `#expect(Bool(true))` with a
    /// comment saying "may or may not intersect ... the important thing is no crash".
    /// It could not go red under any defect. Both cases below are pinned to a measured
    /// value instead.
    @Test("Line-face intersection")
    func lineFaceIntersection() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let faces = box.faces()
        #expect(faces.count == 6, "a box has six faces, got \(faces.count)")

        // faces()[4] is the z = -15 cap. A +Z ray up the axis crosses it exactly once.
        guard let cap = Shape.fromFace(faces[4]) else {
            Issue.record("Shape.fromFace returned nil for the z cap")
            return
        }
        let hits = cap.intersectLine(origin: SIMD3(0, 0, -50), direction: SIMD3(0, 0, 1))
        #expect(hits.count == 1, "a ray crosses a planar cap once, got \(hits.count)")
        if let h = hits.first {
            #expect(abs(h.point.x) < 1e-9)
            #expect(abs(h.point.y) < 1e-9)
            #expect(abs(h.point.z - (-15)) < 1e-9, "cap is at z = -15, got \(h.point.z)")
            // The ray starts 35 units below the cap, so that is the curve parameter.
            #expect(abs(h.parameter - 35) < 1e-9, "expected parameter 35, got \(h.parameter)")
        }
    }

    /// The negative case, which is what makes the positive one mean something: the same
    /// cap, a parallel ray, no intersection.
    @Test("Line parallel to a face does not intersect it")
    func lineParallelToFaceMisses() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let xCap = Shape.fromFace(box.faces()[0])
        else {
            Issue.record("could not build the x = -5 cap")
            return
        }
        // faces()[0] is the x = -5 plane; a +Z ray runs in it, never through it.
        let hits = xCap.intersectLine(origin: SIMD3(0, 0, -50), direction: SIMD3(0, 0, 1))
        #expect(hits.isEmpty, "a ray parallel to a plane cannot cross it, got \(hits.count)")
    }
}
