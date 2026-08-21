import Testing
import simd
@testable import OCCTSwift

/// Issue #254: single-start coaxial-cylinder threads build as a smooth, low-face-count helix
/// under both surviving build modes, `.auto` and `.direct`. The old faceted screw-loft cut path
/// produced a helical scatter of disconnected rectangular notches (roughly 893 faces) rather than
/// a continuous thread, even though the solid was `isValid` with roughly the right volume; #232
/// established the only reason a caller would have chosen that path (a supposed `Bnd_Box` crest
/// overshoot) was an artifact, not real geometry, so the direct build is correct and preferred.
///
/// A third mode, `ThreadBuild.boolean`, forced that faceted cut path unconditionally. It was
/// deprecated as part of this fix and removed at v2.0.0 (#784): this suite used to also assert
/// that `.boolean` matched `.direct` post-fix, and that assertion is gone with the mode, not
/// ported, since there is nothing left to compare against. The two assertions below, about the
/// surviving `.auto`/`.direct` modes, are unrelated to that removal and stay.
@Suite("Issue #254, single-start threads are smooth helices for every surviving build mode")
struct Issue254BuildModes {

    private func shaft(_ build: ThreadBuild) -> Shape? {
        Shape.cylinder(radius: 5, height: 26)?.threadedShaft(
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            spec: ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5),
            length: 26, runout: .none, build: build)
    }

    @Test("`.auto` and `.direct` both yield the same smooth, low-face helix")
    func autoMatchesDirect() {
        guard let auto = shaft(.auto), let direct = shaft(.direct) else {
            Issue.record("build failed"); return
        }
        let fAuto = auto.subShapes(ofType: .face).count
        let fDirect = direct.subShapes(ofType: .face).count
        // The smooth direct helix is a small handful of faces. The old faceted cut produced ~893;
        // a low ceiling cleanly separates "smooth helix" from "notch scatter".
        #expect(fDirect < 40, "direct build should be a smooth low-face helix, got \(fDirect)")
        #expect(fAuto == fDirect, "auto must match direct for single-start, got \(fAuto) vs \(fDirect)")
    }
}
