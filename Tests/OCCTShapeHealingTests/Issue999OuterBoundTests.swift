import Foundation
import Testing
import simd

@testable import OCCTSwift

// #999: `SAWireAnalysis.checkOuterBound(face:precision:)` took a precision and never called
// `ShapeAnalysis_Wire` at all. It ran a `TopExp_Explorer` and answered "does this face have any
// wire", which is true of every valid face, so it neither used the precision it declared nor
// performed the check it was named for. It is now `checkOuterBound(wire:face:)`, the real call.
@Suite("SAWireAnalysis.checkOuterBound performs the check it is named for (#999)")
struct Issue999OuterBoundTests {

    /// A 10x10 planar panel with a 4x4 centred window, so the face carries two wires: one that is
    /// its outer bound and one that is not.
    private func panelWithWindow() -> Shape? {
        guard
            let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let outer = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
            let hole = Wire.polygon3D(
                [SIMD3(3, 3, 0), SIMD3(7, 3, 0), SIMD3(7, 7, 0), SIMD3(3, 7, 0)], closed: true)
        else { return nil }
        return Shape.face(from: plane, outer: outer, innerWires: [hole])
    }

    @Test("The verdict follows the wire, not the face")
    func verdictVariesWithTheWire() {
        guard let face = panelWithWindow() else {
            Issue.record("panel fixture failed")
            return
        }
        let wires = face.subShapes(ofType: .wire)
        // Two wires on one face, so the old implementation's answer ("this face has a wire") is
        // the same for both and this test cannot pass under it.
        #expect(wires.count == 2)
        guard wires.count == 2 else { return }

        let verdicts = wires.map { SAWireAnalysis.checkOuterBound(wire: $0, face: face) }
        // Exactly one of the two is the outer bound. Asserting the partition rather than indexing
        // avoids depending on the order the explorer returns wires in, which is not part of any
        // contract this repo relies on.
        #expect(verdicts.filter { $0 }.count == 1, "verdicts were \(verdicts)")
        #expect(verdicts.filter { !$0 }.count == 1, "verdicts were \(verdicts)")
    }

    @Test("A face's own single wire is its outer bound, so nothing is reported")
    func plainFaceReportsNoProblem() {
        guard
            let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)),
            let outer = Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true),
            let face = Shape.face(from: plane, outer: outer, innerWires: []),
            let wire = face.subShapes(ofType: .wire).first
        else {
            Issue.record("plain face fixture failed")
            return
        }
        #expect(!SAWireAnalysis.checkOuterBound(wire: wire, face: face))
    }
}
