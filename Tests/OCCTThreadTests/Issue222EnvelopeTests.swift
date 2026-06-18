import Testing
import Foundation
import simd
@testable import OCCTSwift

// #222: at coarse pitch / wide crest flats the smooth direct build (#213) bows the crest past the
// nominal major radius (+14–21%). `threadedShaft(build: .boolean)` forces the in-envelope cut path
// (cutter subtracted from a cylinder of radius exactly major/2), so a headless single-start part —
// lead screw, stud, worm — never overshoots nominal. These guard that contract.
@Suite("Issue #222 — coarse-pitch thread envelope")
struct Issue222Envelope {

    /// Max radial extent of a z-axis rod (its outer/crest radius), mesh-independent via the AABB.
    private func crestRadius(_ s: Shape) -> Double {
        let b = s.bounds
        return max(abs(b.max.x), abs(b.min.x), abs(b.max.y), abs(b.min.y))
    }

    @Test("`.boolean` keeps the crest within the nominal major radius (iso68, coarse)")
    func booleanInEnvelopeISO() {
        guard let rod = Shape.cylinder(radius: 6, height: 40) else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
        let threaded = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 40, starts: 1, runout: .none, build: .boolean)
        guard let t = threaded else { #expect(Bool(false), "build: .boolean returned nil"); return }
        #expect(t.isValid)
        let r = crestRadius(t)
        // Nominal major radius is 6.0; allow a small tessellation/healing margin. The direct build
        // measures ~6.85 here (+14%), so 1.02 cleanly separates in-envelope from the overshoot.
        #expect(r <= 6.0 * 1.02, "crest radius \(r) exceeds nominal major radius 6.0 (#222)")
        if let v0 = rod.volume, let v1 = t.volume {
            #expect(v1 < v0, "no material removed — not a real thread")
        }
    }

    @Test("`.boolean` keeps the crest within the nominal major radius (Tr trapezoidal, coarse)")
    func booleanInEnvelopeTrapezoidal() {
        guard let rod = Shape.cylinder(radius: 6, height: 40) else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .trapezoidal, nominalDiameter: 12, pitch: 3.0)
        let threaded = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 40, starts: 1, runout: .none, build: .boolean)
        guard let t = threaded else { #expect(Bool(false), "build: .boolean returned nil"); return }
        #expect(t.isValid)
        let r = crestRadius(t)
        // Direct build is the worst case here: ~7.28 (+21%). Boolean must stay at ~6.0.
        #expect(r <= 6.0 * 1.02, "crest radius \(r) exceeds nominal major radius 6.0 (#222)")
    }

    @Test("default `.auto` still builds a valid single-start rod (no regression)")
    func autoStillBuilds() {
        guard let rod = Shape.cylinder(radius: 5, height: 20) else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        let threaded = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 20)   // build defaults to .auto
        if let t = threaded { #expect(t.isValid) } else { #expect(Bool(false), "auto build returned nil") }
    }
}
