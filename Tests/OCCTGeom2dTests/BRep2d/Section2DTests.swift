import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.144 #73: Shape.section2D

@Suite("v0.144 Shape.section2D")
struct Section2DTests {
    @Test("Section of a box with the XY plane returns a Drawing")
    func sectionBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        // Cut the box through z = 5 (horizontal plane).
        let drawing = box.section2D(
            planeOrigin: SIMD3(5, 5, 5),
            planeNormal: SIMD3(0, 0, 1)
        )
        #expect(drawing != nil)
    }

    @Test("section2DView includes hatch and label")
    func section2DView() {
        guard let box = Shape.box(width: 30, height: 30, depth: 30) else {
            Issue.record("box nil")
            return
        }
        let view = box.section2DView(
            planeOrigin: SIMD3(15, 15, 15),
            planeNormal: SIMD3(0, 0, 1),
            label: "A-A"
        )
        #expect(view != nil)
        if let v = view {
            // Should have a hatch + a text label.
            let hasHatch = v.drawing.annotations.contains {
                if case .hatch = $0 { return true } else { return false }
            }
            let hasLabel = v.drawing.annotations.contains {
                if case .textLabel = $0 { return true } else { return false }
            }
            #expect(hasHatch)
            #expect(hasLabel)
        }
    }

    // #1171: the only existing section2DView test above sections a plain box, which produces one
    // contour loop, so Section2D.swift's internal wire-compounding call (`compound(from:)` before
    // this fix, `Shape.compound(_:)` after) short-circuited on its own single-shape special case
    // in BOTH versions and never actually exercised the divergence between them. This is new
    // coverage for the untested 2-loop path, not a regression test for an observed bug: measured
    // directly (both before and after this fix, in a throwaway probe), the old sequential-`.union()`
    // fuse and the new grouping produce an identical edge count for two genuinely disjoint loops,
    // since OCCT's boolean fuse of non-intersecting wire shapes behaves like a plain union. The two
    // would only be expected to diverge for touching/overlapping loops, which a section of a
    // through-hole never produces.
    @Test("section2DView on a box with a through-hole keeps both the outer and inner contour loops")
    func section2DViewBoxWithHole() {
        guard let box = Shape.box(width: 30, height: 30, depth: 30),
            let cyl = Shape.cylinder(radius: 5, height: 40),
            let cylCentered = cyl.translated(by: SIMD3(15, 15, -5)),
            let withHole = box.subtracting(cylCentered)
        else {
            Issue.record("fixture build failed")
            return
        }
        let view = withHole.section2DView(
            planeOrigin: SIMD3(15, 15, 15),
            planeNormal: SIMD3(0, 0, 1),
            label: "B-B"
        )
        #expect(view != nil)
        if let v = view {
            let edgeCount = v.drawing.visibleEdges?.subShapes(ofType: .edge).count ?? 0
            // Both the outer square loop and the inner circular loop must survive: fewer edges
            // than this would mean one loop was silently dropped by the wire-compounding step.
            #expect(edgeCount >= 5, "expected edges from both loops, got \(edgeCount)")
        }
    }
}
