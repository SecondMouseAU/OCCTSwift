import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Free Boundary Analysis")
struct FreeBoundsTests {
    @Test("Closed solid has no free boundaries")
    func closedSolidNoFreeBounds() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.freeBounds()
        // A watertight solid should have no free boundaries
        #expect(result == nil)
    }

    @Test("Compound of adjacent faces has free boundaries")
    func compoundFacesHasFreeBounds() {
        // ShapeAnalysis_FreeBounds finds boundaries between separate faces in a compound,
        // not edges of a single face. Use two adjacent faces sharing an edge.
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        // Translate second face to be adjacent
        let moved = face2.translated(by: SIMD3(10, 0, 0))!
        let compound = Shape.compound([face1, moved])!
        let result = compound.freeBounds()
        #expect(result != nil)
        if let result {
            #expect(result.closedCount >= 1)
        }
    }

    @Test("Free bounds analysis callable on sphere")
    func freeBoundsSphere() {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.freeBounds()
        // A closed sphere should have no free boundaries
        #expect(result == nil)
    }

    @Test("Fix free bounds callable")
    func fixFreeBoundsCallable() {
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let result = face.fixedFreeBounds(sewingTolerance: 1e-6, closingTolerance: 1e-4)
        // Should return something even if nothing was fixed
        _ = result
    }

    // #310 regression: ShapeAnalysis_FreeBounds crashed (uncatchable SIGSEGV) analyzing a compound
    // of two or more DISJOINT closed faces, not adjacent/touching ones like
    // compoundFacesHasFreeBounds above, which forms a single combined loop and never hit the bug.
    // Each disjoint face's boundary is entirely consumed by its own closed-loop detection with
    // nothing left over, which is exactly what tripped the kernel's uninitialized-handle bug (fixed
    // upstream as OCCT#1377, carried as patch 0004 until the OCCT 8.0.1 re-pin absorbed
    // it). No #expect needed for the crash itself: a regression
    // would abort the whole test process; reaching the assertions below is the real assertion.
    @Test("Disjoint faces in a compound don't crash free-bounds analysis")
    func issue310DisjointFacesFreeBounds() {
        let face1 = Shape.face(from: Wire.rectangle(width: 1, height: 1)!)!
        let face2 = Shape.face(from: Wire.rectangle(width: 1, height: 1)!)!.translated(
            by: SIMD3(5, 5, 0))!
        let compound = Shape.compound([face1, face2])!

        let closedWires = compound.freeBoundsClosedWires(tolerance: 0.01)
        #expect(compound.freeBoundsClosedCount(tolerance: 0.01) == 2)
        #expect(closedWires?.subShapeCount(ofType: .wire) == 2)
        // A valid, empty compound (0 wires) is the correct result here, not nil, both faces
        // are entirely closed, so there's nothing to report as an open free boundary.
        #expect(
            (compound.freeBoundsOpenWires(tolerance: 0.01)?.subShapeCount(ofType: .wire) ?? 0) == 0)
    }
}
