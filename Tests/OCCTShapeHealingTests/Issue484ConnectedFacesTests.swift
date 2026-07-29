import Testing
import simd
@testable import OCCTSwift

/// Issue #484: `Shape.connectedFaces(tolerance:)` (`ShapeFix_FaceConnect`, via
/// `OCCTShapeFixFaceConnect`) had **zero** test coverage anywhere in `Tests/` — grepping
/// `connectedFaces` repo-wide returned only its own declaration. The stale cross-reference index
/// entry (`ShapeFix_FaceConnect → OCCTShapeFixConnect*`, a symbol family that does not exist) would
/// not have led anyone to it either.
///
/// Writing the coverage surfaced a first-of-N defect of the same family as #439/#442/#443: the
/// bridge took the **first** shell an explorer yielded and dropped every other one, so a two-shell
/// compound came back as a single shell. Now every shell is processed and the results reassembled.
@Suite("Issue #484 — Shape.connectedFaces coverage")
struct Issue484ConnectedFacesTests {

    @Test("connectedFaces on a box shell returns a shape with the same face count")
    func boxShellRoundTrips() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box"); return
        }
        guard let connected = box.connectedFaces() else {
            Issue.record("connectedFaces returned nil for a box"); return
        }
        #expect(connected.faces().count == box.faces().count)
    }

    @Test("connectedFaces accepts an explicit tolerance")
    func explicitTolerance() {
        guard let cyl = Shape.cylinder(radius: 4, height: 9) else {
            Issue.record("cylinder"); return
        }
        for tol in [1e-6, 1e-4, 1e-2] {
            guard let connected = cyl.connectedFaces(tolerance: tol) else {
                Issue.record("connectedFaces returned nil at tolerance \(tol)"); continue
            }
            #expect(connected.faces().count == cyl.faces().count)
        }
    }

    /// The first-of-N fix: two disjoint solids in one compound carry two shells, and both must
    /// survive. Before the fix the second shell was silently dropped.
    @Test("connectedFaces keeps every shell of a multi-shell compound")
    func multiShellCompoundKeepsEveryShell() {
        guard let a = Shape.box(width: 10, height: 10, depth: 10),
              let b = Shape.box(width: 6, height: 6, depth: 6)?
                  .translated(by: SIMD3(40, 0, 0)) else {
            Issue.record("boxes"); return
        }
        guard let compound = Shape.compound([a, b]) else {
            Issue.record("compound"); return
        }
        #expect(compound.faces().count == 12)

        guard let connected = compound.connectedFaces() else {
            Issue.record("connectedFaces returned nil for the compound"); return
        }
        // 12, not 6: both shells are processed, not just the first the explorer yields.
        #expect(connected.faces().count == 12)
    }

    @Test("connectedFaces returns nil for a shape with no shell")
    func noShellReturnsNil() {
        guard let wire = Wire.rectangle(width: 5, height: 5),
              let face = Shape.face(from: wire) else {
            Issue.record("rectangle face"); return
        }
        // A lone face is not a shell, and ShapeFix_FaceConnect needs one.
        #expect(face.connectedFaces() == nil)
    }
}
