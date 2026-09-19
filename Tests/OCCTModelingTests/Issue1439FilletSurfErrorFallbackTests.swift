import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1439: `OCCTFilletSurfError`'s doc comment and `catch` fallback were both off by one against
// `FilletSurf_ErrorTypeStatus`'s real enum (`EmptyList=0, EdgeNotG1=1, FacesNotG1=2,
// EdgeNotOnShape=3, NotSharpEdge=4, PbFilletCompute=5`, confirmed directly against the pinned
// `FilletSurf_ErrorTypeStatus.hxx`). The success path already forwarded `StatusError()` verbatim,
// so it was already reporting the real, correctly-numbered enum; only the doc comment describing
// that return value, and the `catch` fallback's literal `4`, were wrong. Under the old (wrong)
// numbering `4` meant "PbFilletCompute", so the fallback read as intentional, but under the real
// enum `4` is `FilletSurf_NotSharpEdge`, a value `FilletSurf_Builder` also returns legitimately, no
// exception involved. That collision is what this suite pins: a caught exception must be
// distinguishable from a genuine "the edge is not sharp" verdict.
//
// `OCCTFilletSurfError` has no Swift caller (`Shape.filletSurfaces(edges:radius:)` only calls
// `OCCTFilletSurfBuild`), so nothing in `swift test` reaches it and these tests call the C bridge
// function directly, matching how `Issue761SharedEdgeCountCapTests` exercises
// `OCCTFaceGetSharedEdges`/`OCCTFaceGetSharedEdgeCount`.
@Suite("OCCTFilletSurfError's exception fallback doesn't collide with a real NotSharpEdge verdict (#1439)")
struct Issue1439FilletSurfErrorFallbackTests {

    /// Calls `OCCTFilletSurfError` with a single edge shape and radius, matching the argument
    /// shape `Shape.filletSurfaces(edges:radius:)` builds for `OCCTFilletSurfBuild`.
    private func filletSurfError(shape: Shape, edge: Shape, radius: Double) -> Int32 {
        let handles: [OCCTShapeRef] = [edge.handle]
        return handles.withUnsafeBufferPointer { buf in
            OCCTFilletSurfError(shape.handle, buf.baseAddress!, Int32(handles.count), radius)
        }
    }

    @Test("A genuine exception inside FilletSurf_Builder reports PbFilletCompute (5), not the value a real NotSharpEdge verdict also uses")
    func exceptionFallbackReportsPbFilletCompute() {
        // A radius of 0 on an otherwise legitimate sharp box edge (shared by exactly two
        // distinct, C0-continuous faces, so it passes every up-front check
        // FilletSurf_Builder's constructor performs) reaches deep into Perform()'s geometric
        // computation, which throws Standard_Failure("StartSol echec"), uncaught anywhere inside
        // FilletSurf_Builder itself. Confirmed directly against the pinned kernel
        // (Libraries/OCCT.xcframework/macos-arm64) with a standalone ground-truth harness before
        // writing this test: deterministic across repeated runs, not a flaky numerical case, and
        // also reproduces with a negative or absurdly large radius on the same edge.
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let edges = box.subShapes(ofType: .edge)
        guard let edge = edges.first else {
            Issue.record("box has no edges")
            return
        }
        let result = filletSurfError(shape: box, edge: edge, radius: 0.0)
        #expect(result == 5, "expected FilletSurf_PbFilletCompute (5) from the catch fallback")
    }

    @Test("A genuine NotSharpEdge verdict from FilletSurf_Builder itself still reports 4, matching the corrected doc")
    func realNotSharpEdgeVerdictReportsFour() {
        // A shape containing only a single face gives none of that face's boundary edges a
        // second owning face, so FilletSurf_InternalBuilder::Add's "does this edge have two
        // distinct owning faces" check fails and it legitimately answers FilletSurf_NotSharpEdge
        // (ordinal 4 in the real enum), with no exception involved at all. This is the success
        // path #1439 does not touch, StatusError() was already forwarded verbatim, so this test
        // is unaffected by the fix either way; it exists to pin the corrected doc comment against
        // OCCT's actual behavior and to give the exception-fallback test above something a
        // pre-fix reader could not tell apart: both reported "4" under the old, wrong numbering,
        // only one of them was a real verdict.
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        guard let face = box.subShapes(ofType: .face).first else {
            Issue.record("box has no faces")
            return
        }
        let faceEdges = face.subShapes(ofType: .edge)
        guard let boundaryEdge = faceEdges.first else {
            Issue.record("face has no boundary edges")
            return
        }
        let result = filletSurfError(shape: face, edge: boundaryEdge, radius: 1.0)
        #expect(result == 4, "expected the real FilletSurf_NotSharpEdge ordinal (4)")
    }
}
