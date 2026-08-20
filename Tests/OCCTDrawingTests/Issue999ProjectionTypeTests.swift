import Foundation
import Testing
import simd

@testable import OCCTSwift

// #999: `Drawing.project(_:direction:type:)` used to hand `OCCTDrawingCreate` a projection type
// the bridge never read, so `.perspective` returned the orthographic projection.
//
// Every assertion here is geometric rather than structural, because the two projections have the
// same topology: four visible edges, one visible face, identical edge count. Only the coordinates
// differ. The fixture is `Shape.box(width:height:depth:)`, which is centred on the origin, so a
// 100x50x30 box viewed down +Z has its near face at z = +15 and a perspective projection from a
// focal distance f scales it by exactly f / (f - 15).
@Suite("Drawing.ProjectionType is honoured (#999)")
struct Issue999ProjectionTypeTests {

    /// Half-width and half-height of a drawing's visible edges in the projection plane.
    private func visibleHalfExtent(_ drawing: Drawing?) -> (x: Double, y: Double)? {
        guard let visible = drawing?.visibleEdges, let box = visible.boundingBox else { return nil }
        return ((box.max.x - box.min.x) / 2, (box.max.y - box.min.y) / 2)
    }

    private func testBox() -> Shape? {
        Shape.box(width: 100, height: 50, depth: 30)
    }

    @Test("Orthographic projects the box at its true size")
    func orthographicIsUnscaled() {
        guard let box = testBox() else {
            Issue.record("box fixture failed")
            return
        }
        guard let extent = visibleHalfExtent(Drawing.project(box, direction: SIMD3(0, 0, 1))) else {
            Issue.record("orthographic projection produced no visible edges")
            return
        }
        #expect(abs(extent.x - 50) < 1e-6)
        #expect(abs(extent.y - 25) < 1e-6)
    }

    @Test("Perspective diverges from orthographic, and by the ratio the focal distance implies")
    func perspectiveDivergesFromOrthographic() {
        guard let box = testBox() else {
            Issue.record("box fixture failed")
            return
        }
        guard
            let ortho = visibleHalfExtent(Drawing.project(box, direction: SIMD3(0, 0, 1))),
            let persp = visibleHalfExtent(
                Drawing.project(box, direction: SIMD3(0, 0, 1), type: .perspective(focus: 50)))
        else {
            Issue.record("a projection produced no visible edges")
            return
        }
        // f / (f - halfDepth) = 50 / 35 = 1.428571...
        let expected = 50.0 * (50.0 / 35.0)
        #expect(abs(persp.x - expected) < 1e-6)
        #expect(persp.x > ortho.x + 1)
        #expect(abs(persp.y - 25.0 * (50.0 / 35.0)) < 1e-6)
    }

    @Test("The focal distance sets the scale, and a longer one converges on orthographic")
    func perspectiveScaleFollowsFocalDistance() {
        guard let box = testBox() else {
            Issue.record("box fixture failed")
            return
        }
        var previous = Double.infinity
        for focus in [20.0, 50.0, 200.0, 1000.0] {
            guard
                let extent = visibleHalfExtent(
                    Drawing.project(
                        box, direction: SIMD3(0, 0, 1), type: .perspective(focus: focus)))
            else {
                Issue.record("perspective projection at focus \(focus) produced no visible edges")
                return
            }
            let expected = 50.0 * (focus / (focus - 15.0))
            #expect(abs(extent.x - expected) < 1e-6, "focus \(focus)")
            // Each longer focal distance is strictly less divergent than the last.
            #expect(extent.x < previous, "focus \(focus) did not converge toward orthographic")
            previous = extent.x
        }
        // The longest focal distance is still measurably wider than orthographic, so this suite
        // never passes by every case collapsing onto the orthographic answer.
        #expect(previous > 50.0)
    }

    @Test("A non-positive focal distance is refused rather than silently reinterpreted")
    func nonPositiveFocusIsRejected() {
        guard let box = testBox() else {
            Issue.record("box fixture failed")
            return
        }
        #expect(
            Drawing.project(box, direction: SIMD3(0, 0, 1), type: .perspective(focus: 0)) == nil)
        #expect(
            Drawing.project(box, direction: SIMD3(0, 0, 1), type: .perspective(focus: -100)) == nil)
        #expect(
            Drawing.project(box, direction: SIMD3(0, 0, 1), type: .perspective(focus: .nan)) == nil)
    }

    @Test("projectFast stays orthographic, which is all HLRBRep_PolyAlgo can do")
    func projectFastIsOrthographic() {
        guard let box = testBox() else {
            Issue.record("box fixture failed")
            return
        }
        guard let extent = visibleHalfExtent(Drawing.projectFast(box, direction: SIMD3(0, 0, 1)))
        else {
            Issue.record("polyhedral projection produced no visible edges")
            return
        }
        #expect(abs(extent.x - 50) < 1e-3)
        #expect(abs(extent.y - 25) < 1e-3)
    }
}
