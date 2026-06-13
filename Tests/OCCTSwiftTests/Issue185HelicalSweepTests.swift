import Testing
import Foundation
import simd
@testable import OCCTSwift

// Issue #185: helical (worm-thread) sweep via auxiliary-spine framing. Separate file
// so edits don't trigger a full ShapeTests.swift recompile (cf. #183).
@Suite("Issue #185 helical sweep — worm-thread helicoid")
struct Issue185HelicalSweepTests {

    // Worm m=1, q=10, z1=1: pitch radius 5, root 3.8, crest 6, axial pitch π.
    // Trapezoid rib at the helix start (5,0,0) in the (radial=X, axis=Z) plane.
    private func wormRib() -> Wire? {
        Wire.polygon3D([
            SIMD3(3.7, 0, -1.26),   // root bottom
            SIMD3(6.0, 0, -0.63),   // crest bottom
            SIMD3(6.0, 0,  0.63),   // crest top
            SIMD3(3.7, 0,  1.26),   // root top
        ], closed: true)
    }

    @Test("helicalSweep builds a valid, radial worm helicoid (not nil) — both handedness",
          arguments: [false, true])
    func helicalSweepIsValidAndRadial(clockwise: Bool) {
        guard let rib = wormRib() else { Issue.record("no rib"); return }
        let worm = Shape.helicalSweep(profile: rib,
                                      axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                                      radius: 5, pitch: .pi, turns: 4.77, clockwise: clockwise)
        // The user's hand-rolled aux-spine returned nil; the helper must not.
        #expect(worm != nil)
        if let worm {
            #expect(worm.isValid)
            // Section stays radial: crest radius ≈ 6, not frenet's ~8.18 over-inflation
            // and certainly not the ~65 of a wrong aux helix.
            let r = worm.bounds.max.x
            #expect(r > 5.0 && r < 7.0)
        }
    }

    // NOTE: a multi-profile `helicalSweep(profiles:)` overload exists for varying
    // sections (thread runout), but each profile must be positioned at its actual helix
    // station (point + radial frame) — non-trivial to set up correctly, so it is exercised
    // by the single-profile path here and documented rather than unit-tested with
    // hand-placed ribs that would mis-locate the section.

    @Test("helicalSweep rejects degenerate parameters")
    func helicalSweepGuards() {
        guard let rib = wormRib() else { Issue.record("no rib"); return }
        #expect(Shape.helicalSweep(profiles: [], axisOrigin: .zero,
                                   axisDirection: SIMD3(0, 0, 1), radius: 5, pitch: .pi, turns: 2) == nil)
        #expect(Shape.helicalSweep(profile: rib, axisOrigin: .zero,
                                   axisDirection: SIMD3(0, 0, 1), radius: 0, pitch: .pi, turns: 2) == nil)
    }
}
