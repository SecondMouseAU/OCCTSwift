import Foundation
import Testing
import simd

@testable import OCCTSwift

/// The ordering precondition that `ShapeAnalysis_Wire` imposes, carried onto `SAWireAnalysis`.
///
/// Filed as #2906.
///
/// Every member except `checkOrder` compares each edge against the next one *in the analyzer's
/// sequence*, so on an out-of-order wire the "next" edge is the wrong one. OCCT's own caller, the
/// shape_healing
/// user guide, treats `CheckOrder()` as a stop condition and returns rather than running the later
/// checks, and per okf/policies/follow-occt-callers.md that early return is the contract.
///
/// `SAWireAnalysisTests` pins the before half: a pristine box face's own wire reports four
/// problems and four distances of 10 * sqrt(2), the face's diagonal. This suite pins the after
/// half, which is the half that makes the mechanism explicit and proves the precondition is
/// reachable from the public API rather than only describable in prose. `WireFixer.fixReorder()`
/// wraps `ShapeFix_Wire::FixReorder` and already existed; the issue's premise that nothing could
/// satisfy the precondition was wrong.
///
/// Every value below is the kernel's own answer from `Scripts/repro/2906/probe.mm`.
@Suite("Wire ordering precondition (#2906)")
struct Issue2906WireOrderPreconditionTests {

    private func boxFaceAndWire() throws -> (face: Shape, wire: Shape) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.subShapes(ofType: .face).first)
        let wire = try #require(face.subShapes(ofType: .wire).first)
        return (face, wire)
    }

    /// Reorders the box face's own wire, which is what the precondition asks for.
    private func reorderedBoxFaceWire() throws -> (face: Shape, wire: Shape) {
        let (face, wire) = try boxFaceAndWire()
        let fixer = try #require(WireFixer(wire: wire, face: face))
        #expect(fixer.fixReorder() == true)  // kernel (probe): the wire really was out of order
        let reordered = try #require(fixer.wire)
        return (face, reordered)
    }

    @Test("fixReorder satisfies the precondition checkOrder reports")
    func fixReorderClearsCheckOrder() throws {
        let (face, wire) = try boxFaceAndWire()
        #expect(SAWireAnalysis.checkOrder(wire: wire, face: face) == true)

        let (fixedFace, fixedWire) = try reorderedBoxFaceWire()
        #expect(SAWireAnalysis.checkOrder(wire: fixedWire, face: fixedFace) == false)
    }

    @Test("the diagonal gaps are an artefact of the ordering, not of the face")
    func gapChecksAreCleanOnAnOrderedWire() throws {
        let (face, wire) = try reorderedBoxFaceWire()

        // Before the reorder these four answer `true` (SAWireAnalysisTests pins that). Nothing
        // about the face changed, only the order the analyzer walks its edges in.
        #expect(SAWireAnalysis.checkGaps3d(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkGaps2d(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkEdgeCurves(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkGap3dEdge(wire: wire, face: face, edgeIndex: 1) == false)

        // ...and the checks that were already clean stay clean, so the reorder did not simply
        // silence the analyzer.
        #expect(SAWireAnalysis.checkConnected(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkSmall(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkDegenerated(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkClosed(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkLacking(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.checkSelfIntersection(wire: wire, face: face) == false)
        #expect(SAWireAnalysis.edgeCount(wire: wire, face: face) == 4)
    }

    @Test("the distances drop from the face diagonal to zero")
    func distancesAreZeroOnAnOrderedWire() throws {
        let (face, wire) = try boxFaceAndWire()
        // 14.142135623730951 is 10 * sqrt(2), the 10x10 face's diagonal rather than any gap in it.
        let diagonal = 10 * 2.0.squareRoot()
        let before = SAWireAnalysis.maxDistance3d(wire: wire, face: face)
        #expect(abs(before - diagonal) < 1e-9)

        let (fixedFace, fixedWire) = try reorderedBoxFaceWire()
        #expect(SAWireAnalysis.minDistance3d(wire: fixedWire, face: fixedFace) == 0)
        #expect(SAWireAnalysis.maxDistance3d(wire: fixedWire, face: fixedFace) == 0)
        #expect(SAWireAnalysis.minDistance2d(wire: fixedWire, face: fixedFace) == 0)
        #expect(SAWireAnalysis.maxDistance2d(wire: fixedWire, face: fixedFace) == 0)
    }
}
