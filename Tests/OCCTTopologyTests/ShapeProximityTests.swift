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

    // MARK: - #1550: indices address the same enumeration face(at:) does

    /// `Issue614FaceOrientationTests.splitBoxCompound()` is a compound of two 10x10x10 halves of a
    /// 20x10x10 box (split at x=10), sharing the single cut face between them: 11 distinct faces,
    /// 12 raw `TopExp_Explorer` occurrences (#541's own repro shape, reused rather than rebuilt,
    /// #1255).
    ///
    /// A probe box centred on the shared face (10, 5, 5) is geometrically close to nothing else on
    /// the compound: every other face is at least 5 units away in Y or Z, or 10 in X. So whichever
    /// raw occurrence `BRepExtrema_ShapeProximity` reports for that probe, `face(at:)` on the
    /// reported index must resolve to a face centred at x=10. Before #1550, the shared face's
    /// SECOND occurrence (the one `TopExp_Explorer` visits walking the second solid) reported its
    /// raw, non-deduplicated position instead of the shared face's actual index in
    /// `Shape.face(at:)`'s enumeration, naming an entirely different, distant face on that solid.
    @Test("proximityFaces indices address the shared-face enumeration face(at:) does (#1550)")
    func proximityFacesIndicesMatchFaceAt() {
        guard let compound = Issue614FaceOrientationTests.splitBoxCompound(),
            let probe = Shape.box(origin: SIMD3(9.5, 4.5, 4.5), width: 1, height: 1, depth: 1)
        else {
            Issue.record("could not build the shared-face fixture")
            return
        }

        let pairs = compound.proximityFaces(with: probe, tolerance: 1.0)
        #expect(!pairs.isEmpty, "the probe sits on the shared face; expected at least one pair")

        for pair in pairs {
            guard let face = compound.face(at: pair.face1Index),
                let asShape = Shape.fromFace(face),
                let box = asShape.boundingBox
            else {
                Issue.record(
                    "face(at: \(pair.face1Index)) is nil for an index proximityFaces returned")
                continue
            }
            let centreX = (box.min.x + box.max.x) / 2
            #expect(
                abs(centreX - 10.0) < 0.01,
                "face(at: \(pair.face1Index)) is centred at x=\(centreX), not the shared face at x=10"
            )
        }
    }
}
