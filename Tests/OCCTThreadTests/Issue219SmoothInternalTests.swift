import Testing
import simd
@testable import OCCTSwift

// #219: fine-pitch internal threads (threadedHole) used to fall to the faceted cutter because the
// `ruled:false` smooth loft self-intersects in a degenerate band around ~14 sections/turn, coming
// back as a no-op boolean. The cut path now escalates the section density past that band, so the
// smooth helical cutter subtracts cleanly. A smooth thread is a handful of BSpline faces; the
// faceted fallback is hundreds — so face count is a robust smooth/faceted discriminator.
@Suite("Issue #219 — smooth fine-pitch internal thread")
struct Issue219SmoothInternal {

    /// The wing-nut body: a cylinder with a coaxial bore, tapped 3/8-16 UNC (fine enough to have
    /// hit the degenerate band before the fix).
    private func tappedWingNutBody() -> Shape? {
        guard let cyl = Shape.cylinder(radius: 8, height: 9),
              let bore = Shape.cylinder(at: SIMD3(0, 0, -1), direction: SIMD3(0, 0, 1),
                                        radius: 9.525 / 2, height: 11),
              let body0 = cyl.subtracting(bore) else { return nil }
        let spec = ThreadSpec(form: .unified, nominalDiameter: 9.525, pitch: 25.4 / 16)
        return body0.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, depth: 9)
    }

    @Test("3/8-16 UNC internal thread cuts smooth (few faces), not faceted")
    func smoothNotFaceted() {
        guard let t = tappedWingNutBody() else { #expect(Bool(false), "threadedHole returned nil"); return }
        #expect(t.isValid)
        let faces = t.subShapes(ofType: .face).count
        // Smooth helicoid is ~15 faces here; the pre-fix faceted fallback was ~247. 40 cleanly splits them.
        #expect(faces < 40, "internal thread came out faceted (\(faces) faces) — smooth path not taken (#219)")
    }

    @Test("the smooth internal cut still removes a thread's worth of material")
    func removesMaterial() {
        guard let cyl = Shape.cylinder(radius: 8, height: 9),
              let bore = Shape.cylinder(at: SIMD3(0, 0, -1), direction: SIMD3(0, 0, 1),
                                        radius: 9.525 / 2, height: 11),
              let body0 = cyl.subtracting(bore),
              let v0 = body0.volume else { #expect(Bool(false)); return }
        let spec = ThreadSpec(form: .unified, nominalDiameter: 9.525, pitch: 25.4 / 16)
        guard let t = body0.threadedHole(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, depth: 9),
              let v1 = t.volume else { #expect(Bool(false)); return }
        #expect(v1 < v0, "no material removed")
        #expect(v1 > v0 * 0.8, "removed implausibly much for a 3/8-16 internal thread")
    }
}
