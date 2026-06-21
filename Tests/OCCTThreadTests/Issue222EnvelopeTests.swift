import Testing
import Foundation
import simd
@testable import OCCTSwift

// #222 (revised by #232 / #254): the smooth direct build (#213) was *reported* to bow the crest past
// the nominal major radius at coarse pitch / wide crest flats (+14–21%). #232 then showed that
// "overshoot" is a `Shape.bounds` (OCCT `Bnd_Box`) **control-hull artifact** — the B-spline convex
// hull bulges out, but the real surface (optimal box / mesh vertices) sits exactly at nominal. So the
// direct build is genuinely in-envelope; the old `.boolean` cut path it motivated has no advantage and
// is deprecated (#254). These tests now guard the *true* contract, measured tightly.
@Suite("Issue #222 — coarse-pitch thread crest is in-envelope (tight measure)")
struct Issue222Envelope {

    /// Crest radius from the **optimal** box (tight; AddOptimal) — the ground truth, not `Bnd_Box`.
    private func crestRadiusOptimal(_ s: Shape) -> Double? {
        guard let b = s.boundingBoxOptimal() else { return nil }
        return max(abs(b.max.x), abs(b.min.x), abs(b.max.y), abs(b.min.y))
    }

    /// Crest radius from mesh vertices (independent tight ground truth — verts lie on real faces).
    private func crestRadiusMesh(_ s: Shape) -> Double? {
        guard let m = s.mesh(linearDeflection: 0.05) else { return nil }
        return m.vertices.reduce(0.0) { max($0, Double((($1.x * $1.x) + ($1.y * $1.y)).squareRoot())) }
    }

    @Test("Direct build keeps the crest within the nominal major radius (iso68, coarse)")
    func directInEnvelopeISO() {
        guard let rod = Shape.cylinder(radius: 6, height: 40) else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)   // nominal major radius 6.0
        let threaded = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 40, build: .direct)
        guard let t = threaded else { #expect(Bool(false), "direct build returned nil"); return }
        #expect(t.isValid)
        // Both tight measures must sit at ~6.0 (the Bnd_Box `bounds` reads ~6.85 here — the artifact).
        if let r = crestRadiusOptimal(t) { #expect(r <= 6.0 * 1.005, "optimal crest \(r) > nominal 6.0") }
        if let r = crestRadiusMesh(t)    { #expect(r <= 6.0 * 1.005, "mesh crest \(r) > nominal 6.0") }
        if let v0 = rod.volume, let v1 = t.volume { #expect(v1 < v0, "no material removed — not a real thread") }
    }

    @Test("Direct build keeps the crest within the nominal major radius (Tr trapezoidal, coarse)")
    func directInEnvelopeTrapezoidal() {
        guard let rod = Shape.cylinder(radius: 6, height: 40) else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .trapezoidal, nominalDiameter: 12, pitch: 3.0)
        let threaded = rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                         spec: spec, length: 40, build: .direct)
        guard let t = threaded else { #expect(Bool(false), "direct build returned nil"); return }
        #expect(t.isValid)
        // `bounds` reads ~7.28 here (+21%); the real crest is at 6.0.
        if let r = crestRadiusOptimal(t) { #expect(r <= 6.0 * 1.005, "optimal crest \(r) > nominal 6.0") }
        if let r = crestRadiusMesh(t)    { #expect(r <= 6.0 * 1.005, "mesh crest \(r) > nominal 6.0") }
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
