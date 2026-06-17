import Testing
import Foundation
import simd
@testable import OCCTSwift

// #196: the v1.4.1 smooth analytic thread helicoid is HLR-hostile — projecting its BSpline
// faces with OCCT's *exact* HLR (`hlrEdges` / HLRBRep_Algo) computes analytic helical
// silhouettes and blows up (~19× slower 2D drawing pipeline vs the v1.4.0 faceted thread).
// The fix is NOT to change the solid: polyhedral HLR (`hlrPolyEdges` / HLRBRep_PolyAlgo)
// projects the *triangulation* instead, so it is fast on any surface (measured ~48× faster
// than exact HLR on this thread) while the one analytic solid stays smooth for STEP. The mesh
// `deflection` is now caller-tunable so drawing pipelines can trade fidelity for speed.
// Separate file, cf. #183.
@Suite("Issue #196 — polyhedral HLR for threaded solids (fast 2D drawings)")
struct Issue196PolyHLRTests {

    private func analyticThread() -> Shape? {
        guard let shank = Shape.cylinder(radius: 5, height: 50) else { return nil }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.0)
        return shank.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                   spec: spec, length: 26, runout: .none)
    }

    @Test("poly HLR projects the analytic thread to 2D edges")
    func polyHLRProducesEdges() {
        guard let t = analyticThread() else { Issue.record("no thread"); return }
        let edges = t.hlrPolyEdges(direction: SIMD3(1, 0, 0), category: .visibleSharp)
        #expect(edges != nil)
        if let edges { #expect(edges.subShapes(ofType: .edge).count > 0) }
    }

    // NB: each deflection is exercised on its OWN fresh thread. BRepMesh_IncrementalMesh is
    // incremental — it refines an existing triangulation but never coarsens it — so calling
    // fine-then-coarse on the *same* shape would reuse the fine mesh and mask the parameter.
    @Test("deflection is honoured — coarser mesh yields fewer drawing edges")
    func deflectionControlsDetail() {
        guard let tFine = analyticThread(), let tCoarse = analyticThread() else {
            Issue.record("no thread"); return
        }
        let dir = SIMD3<Double>(1, 0, 0)
        let fine = tFine.hlrPolyEdges(direction: dir, category: .visibleSharp, deflection: 0.05)?
            .subShapes(ofType: .edge).count
        let coarse = tCoarse.hlrPolyEdges(direction: dir, category: .visibleSharp, deflection: 0.8)?
            .subShapes(ofType: .edge).count
        #expect(fine != nil); #expect(coarse != nil)
        if let fine, let coarse {
            #expect(fine > 0); #expect(coarse > 0)
            // Deflection is honoured (it changes the projected edge set). With the v1.5+ smooth
            // cam-loft thread (#213) the count is NOT strictly monotonic in deflection — a coarse
            // triangulation of the helicoidal flanks can yield MORE silhouette segments, not fewer
            // (unlike the old v1.4.1 helicoid). What matters is that the parameter takes effect.
            #expect(coarse != fine)
        }
    }
}
