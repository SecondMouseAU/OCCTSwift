import Testing
import simd
@testable import OCCTSwift

/// Issue #254: `threadedShaft(build: .boolean)` (and `.boolean` generally) forced the faceted
/// screw-loft cut path, whose helical cutter is the classic OCCT BOP trap — the subtraction comes
/// back as a helical scatter of **disconnected rectangular notches** (hundreds of faces) rather than
/// a continuous thread, even though the solid is `isValid` with roughly the right volume. Because
/// #232 disproved the only reason `.boolean` existed (a `Bnd_Box`-artifact "crest overshoot" — the
/// direct build is in-envelope, see `Issue222Envelope`), `.boolean` is now deprecated and
/// single-start coaxial cylinders take the smooth direct build for **every** build mode.
@Suite("Issue #254 — single-start threads are smooth helices for every build mode")
struct Issue254BuildModes {

    private func shaft(_ build: ThreadBuild) -> Shape? {
        Shape.cylinder(radius: 5, height: 26)?.threadedShaft(
            axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
            spec: ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5),
            length: 26, runout: .none, build: build)
    }

    // Exercise the deprecated `.boolean` without a deprecation warning (calling it from a deprecated
    // context suppresses the diagnostic) — we deliberately prove it no longer regresses.
    @available(*, deprecated)
    private func booleanShaft() -> Shape? { shaft(.boolean) }

    @Test("`.auto`, `.direct` and (deprecated) `.boolean` all yield the same smooth helix")
    func allModesAreDirect() {
        guard let auto = shaft(.auto), let direct = shaft(.direct), let boolean = booleanShaft() else {
            Issue.record("build failed"); return
        }
        let fAuto = auto.subShapes(ofType: .face).count
        let fDirect = direct.subShapes(ofType: .face).count
        let fBool = boolean.subShapes(ofType: .face).count
        // The smooth direct helix is a small handful of faces. The old faceted cut produced ~893;
        // a low ceiling cleanly separates "smooth helix" from "notch scatter".
        #expect(fDirect < 40, "direct build should be a smooth low-face helix, got \(fDirect)")
        #expect(fAuto == fDirect, "auto must match direct for single-start, got \(fAuto) vs \(fDirect)")
        #expect(fBool == fDirect, "deprecated .boolean must now match direct, got \(fBool) vs \(fDirect)")
    }

    @Test("Single-start `.boolean` crest is in-envelope and material was removed")
    func booleanIsInEnvelope() {
        guard let t = booleanShaft() else { Issue.record("boolean build failed"); return }
        #expect(t.isValid)
        if let o = t.boundingBoxOptimal() {
            let r = max(abs(o.max.x), abs(o.min.x), abs(o.max.y), abs(o.min.y))
            #expect(r <= 5.0 * 1.005, "crest \(r) should be at nominal 5.0")
        }
        if let blank = Shape.cylinder(radius: 5, height: 26)?.volume, let v = t.volume {
            #expect(v < blank, "no material removed — not a real thread")
        }
    }
}
