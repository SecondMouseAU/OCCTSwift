import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1030: `.perspective(focus:)` anchors its projection frame at the WORLD origin, not at the shape.
// `OCCTDrawingCreate` builds `gp_Ax2(gp_Pnt(0, 0, 0), viewDir)` unconditionally, so the eye sits at
// `focus * direction` and `HLRAlgo_Projector::Project` divides by `R = 1 - Z/focus` with `Z`
// measured from that origin. A shape at or beyond the eye has `R <= 0` and used to come back
// mirrored through the origin rather than refused, which reads as success at the call site.
//
// Every fixture here is the corner-based `Shape.box(origin:width:height:depth:)`, so the box's own
// coordinates are stated rather than derived: the centred `Shape.box(width:height:depth:)` would
// put the interesting extents half a depth away from where they are written. Assertions are on the
// projected coordinates and their SIGN, because a mirrored drawing has the same edge count and the
// same bounding-box width as a correct one, and only the sign separates them.
@Suite("Perspective eye anchor and the regime beyond it (#1030)")
struct Issue1030PerspectiveEyeAnchorTests {

    /// The projected X range of a drawing's visible edges, sign included.
    private func visibleXRange(_ drawing: Drawing?) -> (min: Double, max: Double)? {
        guard let visible = drawing?.visibleEdges, let box = visible.boundingBox else { return nil }
        return (box.min.x, box.max.x)
    }

    /// A 10-unit cube spanning x [xMin, xMin + 10] and z [zMin, zMin + 10].
    private func cube(xMin: Double, zMin: Double) -> Shape? {
        Shape.box(origin: SIMD3(xMin, -5, zMin), width: 10, height: 10, depth: 10)
    }

    @Test("A shape wholly beyond the eye is refused, not drawn mirrored")
    func shapeBeyondTheEyeIsRefused() {
        guard let far = cube(xMin: 20, zMin: 1000) else {
            Issue.record("box fixture failed")
            return
        }
        // The eye is at z = 50 and the box spans z 1000 to 1010, so every point has R < 0.
        // Measured against the unfixed bridge: seven edges spanning x [-1.579, -1.042], where the
        // correct projection of a box at x [20, 30] cannot have a negative coordinate at all.
        #expect(
            Drawing.project(far, direction: SIMD3(0, 0, 1), type: .perspective(focus: 50)) == nil)
    }

    @Test("An eye plane cutting the shape is refused, not drawn half mirrored")
    func eyePlaneCuttingTheShapeIsRefused() {
        guard let near = cube(xMin: 20, zMin: 0) else {
            Issue.record("box fixture failed")
            return
        }
        // The eye is at z = 5.5, inside the box's z span of 0 to 10, so the near half has R < 0 and
        // the far half R > 0. Measured against the unfixed bridge: four edges spanning
        // x [-24.444, 20], one half reflected against the other.
        #expect(
            Drawing.project(near, direction: SIMD3(0, 0, 1), type: .perspective(focus: 5.5)) == nil)
    }

    @Test("An eye exactly on a face is refused rather than divided by zero")
    func eyeExactlyOnAFaceIsRefused() {
        guard let near = cube(xMin: 20, zMin: 0) else {
            Issue.record("box fixture failed")
            return
        }
        // R is exactly 0 on the top face. Measured against the unfixed bridge: a real drawing whose
        // x range starts at -1.13e17.
        #expect(
            Drawing.project(near, direction: SIMD3(0, 0, 1), type: .perspective(focus: 10)) == nil)
    }

    @Test("The eye is anchored at the world origin, so the scale follows the shape's position")
    func eyeIsAnchoredAtTheWorldOriginNotTheShape() {
        guard let atOrigin = cube(xMin: -5, zMin: 0), let farAway = cube(xMin: -5, zMin: 1000)
        else {
            Issue.record("box fixture failed")
            return
        }
        // Two geometrically identical boxes, each viewed with the eye 40 units from its near face.
        // An eye anchored on the shape would project them identically. An eye anchored at the world
        // origin scales by focus / (focus - z), which is 50/40 for the first and 1050/40 for the
        // second: a factor of 21 between two drawings of the same cube.
        guard
            let near = visibleXRange(
                Drawing.project(atOrigin, direction: SIMD3(0, 0, 1), type: .perspective(focus: 50))),
            let far = visibleXRange(
                Drawing.project(
                    farAway, direction: SIMD3(0, 0, 1), type: .perspective(focus: 1050)))
        else {
            Issue.record("a projection produced no visible edges")
            return
        }
        #expect(abs(near.max - 6.25) < 1e-6)
        #expect(abs(far.max - 131.25) < 1e-6)
        #expect(abs(far.max / near.max - 21.0) < 1e-5)
        // Both are centred on x = 0, so neither is mirrored or displaced.
        #expect(abs(near.min + near.max) < 1e-6)
        #expect(abs(far.min + far.max) < 1e-6)
    }

    @Test("A shape behind the picture plane still projects, shrunken and the right way round")
    func shapeBehindThePicturePlaneIsAccepted() {
        guard let behind = cube(xMin: 20, zMin: -1010) else {
            Issue.record("box fixture failed")
            return
        }
        // Negative Z is the far side of the picture plane from the eye, not the far side of the
        // eye, so R is large and positive and the correct answer is a small, unmirrored drawing.
        // The guard must not reject this. The two faces divide by different R, and the extremes of
        // the projected range come from opposite ones: R is 1 + 1000/50 = 21 on the face at
        // z = -1000 and 1 + 1010/50 = 21.2 on the face at z = -1010, so the smallest projected x is
        // the box's smallest x over the LARGER R, and the largest is its largest x over the smaller.
        guard
            let range = visibleXRange(
                Drawing.project(behind, direction: SIMD3(0, 0, 1), type: .perspective(focus: 50)))
        else {
            Issue.record("perspective projection behind the picture plane produced no edges")
            return
        }
        #expect(range.min > 0)
        #expect(abs(range.min - 20.0 / 21.2) < 1e-6)
        #expect(abs(range.max - 30.0 / 21.0) < 1e-6)
    }

    @Test("A focal distance just clear of the shape is accepted, however extreme the scale")
    func extremeButValidFocusIsAccepted() {
        guard let near = cube(xMin: 20, zMin: 0) else {
            Issue.record("box fixture failed")
            return
        }
        // The eye is 0.01 beyond the top face. The magnification is enormous and entirely correct,
        // so the guard has to admit it: rejecting everything uncomfortable would hide the defect
        // rather than fix it.
        guard
            let range = visibleXRange(
                Drawing.project(near, direction: SIMD3(0, 0, 1), type: .perspective(focus: 10.01)))
        else {
            Issue.record("perspective projection just clear of the shape produced no edges")
            return
        }
        #expect(range.min > 0)
        #expect(range.max > 1000)
    }
}
