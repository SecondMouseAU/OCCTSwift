import Foundation
import Testing
import simd

@testable import OCCTSwift

// #196: the v1.4.1 smooth analytic thread helicoid is HLR-hostile, projecting its BSpline
// faces with OCCT's *exact* HLR (`hlrEdges` / HLRBRep_Algo) computes analytic helical
// silhouettes and blows up (~19× slower 2D drawing pipeline vs the v1.4.0 faceted thread).
// The fix is NOT to change the solid: polyhedral HLR (`hlrPolyEdges` / HLRBRep_PolyAlgo)
// projects the *triangulation* instead, so it is fast on any surface (measured ~48× faster
// than exact HLR on this thread) while the one analytic solid stays smooth for STEP. The mesh
// `deflection` is now caller-tunable so drawing pipelines can trade fidelity for speed.
// Separate file, cf. #183.
@Suite("Issue #196, polyhedral HLR for threaded solids (fast 2D drawings)")
struct Issue196PolyHLRTests {

    private func analyticThread() -> Shape? {
        guard let shank = Shape.cylinder(radius: 5, height: 50) else { return nil }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.0)
        return shank.threadedShaft(
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            spec: spec, length: 26, runout: .none)
    }

    @Test("poly HLR projects the analytic thread to 2D edges")
    func polyHLRProducesEdges() {
        guard let t = analyticThread() else {
            Issue.record("no thread")
            return
        }
        let edges = t.hlrPolyEdges(direction: SIMD3(1, 0, 0), category: .visibleSharp)
        #expect(edges != nil)
        if let edges { #expect(edges.subShapes(ofType: .edge).count > 0) }
    }

    // NB: each deflection is exercised on its OWN fresh thread. BRepMesh_IncrementalMesh is
    // incremental, it refines an existing triangulation but never coarsens it, so calling
    // fine-then-coarse on the *same* shape would reuse the fine mesh and mask the parameter.
    //
    // #766: this used to be named "coarser mesh yields fewer drawing edges" and asserted only
    // `coarse != fine` on the visible-sharp count, while its own comment said that count is not
    // monotonic. What the kernel reports for this thread viewed along +X, measured by
    // Scripts/repro/766-thread-193-222/probe-evidence-fix.mm (transcript-evidence-fix.txt), and
    // what this shape gives in-process:
    //
    //     deflection   visibleSharp   visibleOutline
    //     0.05         1873           17041
    //     0.8          2089            3578
    //
    // The silhouette count does what the old name claimed: the coarse mesh draws about a fifth of
    // the fine one's outline edges. The sharp count goes the other way, 11% MORE on the coarse
    // mesh, and is not monotonic in the deflection at all (1741 at 0.1, 1873 at 0.05, 1912 at
    // 0.4), so it is not a measure of detail and the outline count is. The kernel, driven with
    // BRepMesh_IncrementalMesh and HLRBRep_PolyAlgo directly on the same BREP, gives the bridge's
    // counts exactly, so this is the kernel's behaviour and not the bridge's; both directions are
    // pinned as it reports them, not as a rule about deflection. The counts are checked to 1%
    // because a BREP round trip of the same shape moves them slightly (1869 and 17088 at 0.05),
    // while a wrong deflection moves the outline count by far more.
    @Test("deflection is honoured, a coarser mesh draws fewer outline edges and more sharp ones")
    func deflectionControlsDetail() throws {
        let tFine = try #require(analyticThread())
        let tCoarse = try #require(analyticThread())
        let dir = SIMD3<Double>(1, 0, 0)
        func edgeCounts(_ thread: Shape, deflection: Double) -> (sharp: Int, outline: Int)? {
            guard
                let sharp = thread.hlrPolyEdges(
                    direction: dir, category: .visibleSharp, deflection: deflection)?
                    .subShapes(ofType: .edge).count,
                let outline = thread.hlrPolyEdges(
                    direction: dir, category: .visibleOutline, deflection: deflection)?
                    .subShapes(ofType: .edge).count
            else { return nil }
            return (sharp, outline)
        }
        func within1Percent(_ n: Int, of expected: Int) -> Bool {
            abs(n - expected) * 100 <= expected
        }
        let fine = try #require(edgeCounts(tFine, deflection: 0.05))
        let coarse = try #require(edgeCounts(tCoarse, deflection: 0.8))
        #expect(
            coarse.outline < fine.outline,
            "outline: coarse \(coarse.outline), fine \(fine.outline)")
        #expect(
            coarse.sharp > fine.sharp, "sharp: coarse \(coarse.sharp), fine \(fine.sharp)")
        #expect(within1Percent(fine.outline, of: 17041), "fine outline \(fine.outline)")
        #expect(within1Percent(coarse.outline, of: 3578), "coarse outline \(coarse.outline)")
        #expect(within1Percent(fine.sharp, of: 1873), "fine sharp \(fine.sharp)")
        #expect(within1Percent(coarse.sharp, of: 2089), "coarse sharp \(coarse.sharp)")
    }
}
