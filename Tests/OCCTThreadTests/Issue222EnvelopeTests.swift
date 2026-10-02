import Foundation
import Testing
import simd

@testable import OCCTSwift

// #222 (revised by #232 / #254): the smooth direct build (#213) was *reported* to bow the crest past
// the nominal major radius at coarse pitch / wide crest flats (+14-21%). #232 then showed that
// "overshoot" is a `Shape.bounds` (OCCT `Bnd_Box`) **control-hull artifact**, the B-spline convex
// hull bulges out, but the real surface (optimal box / mesh vertices) sits exactly at nominal. So the
// direct build is genuinely in-envelope; the old `.boolean` cut path it motivated has no advantage and
// is deprecated (#254). These tests now guard the *true* contract, measured tightly.
//
// #2938: they used to ask for `build: .direct` and check nothing only the direct build satisfies,
// which #2369's own evidence table admitted ("under `nodirect` it stays green"), and every
// assertion sat inside an `if let` on the measurement it was checking, so a nil crest or a nil
// volume skipped its `#expect` and the test passed. The face count is what separates the two
// paths: the direct build gives single digits where the faceted cut fallback gives hundreds
// (`Issue257MultiStartTests` pins `< 40` for the same reason). Every number below is the kernel's
// own, from `Scripts/repro/766-thread-193-222/transcript.txt`.
@Suite("Issue #222, coarse-pitch thread crest is in-envelope (tight measure)")
struct Issue222Envelope {

    /// Crest radius from the **optimal** box (tight; AddOptimal), the ground truth, not `Bnd_Box`.
    private func crestRadiusOptimal(_ s: Shape) throws -> Double {
        let b = try #require(s.boundingBoxOptimal(), "optimal bounding box was nil")
        return max(abs(b.max.x), abs(b.min.x), abs(b.max.y), abs(b.min.y))
    }

    /// The direct build's face count. `222_iso`, `222_trap` and `222_auto` all measure 7 against
    /// the pinned kernel, where the faceted cut fallback gives hundreds, so this is the assertion
    /// that reads the `build:` argument the test's name is about.
    private func expectDirectBuild(_ s: Shape, _ label: String) {
        let faces = s.subShapes(ofType: .face).count
        #expect(
            faces == 7,
            "\(label) has \(faces) faces; the direct build gives 7 and the faceted cut fallback gives hundreds"
        )
    }

    @Test("Direct build keeps the crest within the nominal major radius (iso68, coarse)")
    func directInEnvelopeISO() throws {
        let rod = try #require(Shape.cylinder(radius: 6, height: 40))
        // Nominal major radius 6.0.
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
        let t = try #require(
            rod.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                spec: spec, length: 40, build: .direct),
            "direct build returned nil")

        #expect(t.isValid)
        expectDirectBuild(t, "222_iso")
        // Both tight measures must sit at ~6.0 (the Bnd_Box `bounds` reads ~6.85 here, the artifact).
        // Measured: optimal 6.00000696, mesh 6.00000715.
        let optimal = try crestRadiusOptimal(t)
        #expect(optimal <= 6.0 * 1.005, "optimal crest \(optimal) > nominal 6.0")
        #expect(
            optimal >= 6.0 * 0.995, "optimal crest \(optimal) < nominal 6.0, no thread cut here")
        let mesh = try #require(
            meshMaxRadialExtent(t, deflection: 0.05), "mesh crest measurement was nil")
        #expect(mesh <= 6.0 * 1.005, "mesh crest \(mesh) > nominal 6.0")
        #expect(mesh >= 6.0 * 0.995, "mesh crest \(mesh) < nominal 6.0")

        let v0 = try #require(rod.volume, "stock volume was nil")
        let v1 = try #require(t.volume, "threaded volume was nil")
        #expect(abs(v0 - 4523.89342) < 1e-4, "stock volume \(v0) is not the measured 4523.89342")
        #expect(abs(v1 - 3772.20068) < 1e-4, "threaded volume \(v1) is not the measured 3772.20068")
        #expect(v1 < v0, "no material removed, not a real thread")
    }

    @Test("Direct build keeps the crest within the nominal major radius (Tr trapezoidal, coarse)")
    func directInEnvelopeTrapezoidal() throws {
        let rod = try #require(Shape.cylinder(radius: 6, height: 40))
        let spec = ThreadSpec(form: .trapezoidal, nominalDiameter: 12, pitch: 3.0)
        let t = try #require(
            rod.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                spec: spec, length: 40, build: .direct),
            "direct build returned nil")

        #expect(t.isValid)
        expectDirectBuild(t, "222_trap")
        // `bounds` reads ~7.28 here (+21%); the real crest is at 6.0. Measured: optimal
        // 6.00000658, mesh 6.00000668.
        let optimal = try crestRadiusOptimal(t)
        #expect(optimal <= 6.0 * 1.005, "optimal crest \(optimal) > nominal 6.0")
        #expect(
            optimal >= 6.0 * 0.995, "optimal crest \(optimal) < nominal 6.0, no thread cut here")
        let mesh = try #require(
            meshMaxRadialExtent(t, deflection: 0.05), "mesh crest measurement was nil")
        #expect(mesh <= 6.0 * 1.005, "mesh crest \(mesh) > nominal 6.0")
        #expect(mesh >= 6.0 * 0.995, "mesh crest \(mesh) < nominal 6.0")

        let v0 = try #require(rod.volume, "stock volume was nil")
        let v1 = try #require(t.volume, "threaded volume was nil")
        #expect(abs(v0 - 4523.89342) < 1e-4, "stock volume \(v0) is not the measured 4523.89342")
        #expect(abs(v1 - 3521.6745) < 1e-4, "threaded volume \(v1) is not the measured 3521.6745")
        #expect(v1 < v0, "no material removed, not a real thread")
    }

    @Test("default `.auto` still builds a valid single-start rod (no regression)")
    func autoStillBuilds() throws {
        let rod = try #require(Shape.cylinder(radius: 5, height: 20))
        let spec = ThreadSpec(form: .iso68, nominalDiameter: 10, pitch: 1.5)
        let t = try #require(
            rod.threadedShaft(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                spec: spec, length: 20),  // build defaults to .auto
            "auto build returned nil")

        #expect(t.isValid)
        // `.auto` and `.direct` resolve to the same path for a coaxial cylinder (#254), which is
        // the claim this pins: the same 7 faces, not a faceted fallback.
        expectDirectBuild(t, "222_auto")
        let v1 = try #require(t.volume, "threaded volume was nil")
        #expect(abs(v1 - 1302.85264) < 1e-4, "threaded volume \(v1) is not the measured 1302.85264")
    }
}
