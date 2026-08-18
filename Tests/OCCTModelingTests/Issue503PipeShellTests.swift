// #503: every Add()-based pipe shell is one bridge function.
//
// Four bridge entry points used to build their own single-profile MakePipeShell, and two of
// them could not express half the OCCTPipeMode enum they accepted: they swept Frenet instead
// and returned a shape that looked like a success. These tests pin the unified contract:
// a single-profile sweep is the multi-section sweep with one section, and a mode the caller
// asked for is either honoured or refused, never quietly swapped.

import Testing
import Foundation
@testable import OCCTSwift

@Suite("Pipe shell unification (#503)")
struct Issue503PipeShellTests {

    /// Curved enough that Frenet, corrected Frenet and a fixed binormal all disagree.
    /// A straight spine will not do: with no torsion the modes coincide, which is how the
    /// silent fall-through survived a test suite that only ever swept straight lines.
    ///
    /// Not private: Issue598PipeShellFrenetModeTests (same target) reuses this fixture directly
    /// rather than keeping a byte-for-byte copy the two files could silently drift apart on.
    static func curvedSpine() -> Wire? {
        Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 5, 0), SIMD3(20, -5, 10), SIMD3(30, 0, 10)])
    }

    /// An L-shaped spine, so the corner transition modes have a corner to act on.
    static func corneredSpine() -> Wire? {
        Wire.path([SIMD3(0, 0, 0), SIMD3(0, 0, 20), SIMD3(15, 0, 20)])
    }

    static func fingerprint(_ s: Shape?) -> (volume: Double, faces: Int)? {
        guard let s, let v = s.volume else { return nil }
        return (v, s.faces().count)
    }

    // MARK: - The unification invariant

    @Test("a one-profile multi-section sweep is the single-profile sweep, in every mode")
    func oneProfileMatchesTheMultiSectionForm() {
        guard let curved = Self.curvedSpine(),
              let straight = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
              let aux = Wire.line(from: SIMD3(5, 0, 0), to: SIMD3(5, 8, 20)),
              let rect = Wire.rectangle(width: 5, height: 3),
              let circle = Wire.circle(radius: 2) else {
            Issue.record("Could not build the fixtures"); return
        }

        let cases: [(String, Wire, Wire, PipeSweepMode)] = [
            ("frenet", curved, rect, .frenet),
            ("correctedFrenet", curved, rect, .correctedFrenet),
            ("fixed", curved, rect, .fixed(binormal: SIMD3(0, 0, 1))),
            ("auxiliary", straight, circle, .auxiliary(spine: aux)),
        ]

        for (name, spine, profile, mode) in cases {
            let single = Self.fingerprint(
                Shape.pipeShell(spine: spine, profile: profile, mode: mode))
            let multi = Self.fingerprint(
                Shape.pipeShellMultiSection(spine: spine, profiles: [profile], mode: mode))
            #expect(single != nil, "single-profile \(name) sweep failed")
            #expect(multi != nil, "one-section \(name) sweep failed")
            if let single, let multi {
                #expect(single.volume.isApproximatelyEqual(to: multi.volume, tolerance: 1e-9),
                        "\(name): \(single.volume) vs \(multi.volume)")
                #expect(single.faces == multi.faces, "\(name) face count")
            }
        }
    }

    // MARK: - Modes are honoured, not substituted

    @Test("a fixed binormal builds a different solid from Frenet on a curved spine")
    func fixedBinormalDiffersFromFrenet() {
        guard let spine = Self.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Could not build the fixtures"); return
        }
        let frenet = Self.fingerprint(Shape.pipeShell(spine: spine, profile: profile, mode: .frenet))
        let fixed = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile, mode: .fixed(binormal: SIMD3(0, 0, 1))))

        if let frenet, let fixed {
            // 177.347557, not 180.286724: that was the pre-#598 value, and it was the
            // corrected-Frenet solid, not the Frenet one. .frenet and .correctedFrenet were
            // wired to each other's OCCT mode. This literal moved when #598 fixed the swap;
            // Issue598PipeShellFrenetModeTests pins the fix itself against an independent oracle.
            #expect(frenet.volume.isApproximatelyEqual(to: 177.347557, tolerance: 1e-5))
            #expect(fixed.volume.isApproximatelyEqual(to: 149.999816, tolerance: 1e-5))
            #expect(!frenet.volume.isApproximatelyEqual(to: fixed.volume, tolerance: 1e-6))
        } else {
            Issue.record("Both sweeps must build")
        }
    }

    /// The regression this issue actually fixes. Asking for a transition mode used to force
    /// the sweep through a bridge function that understood only Frenet and corrected Frenet,
    /// so `.fixed(binormal:)` came back as a Frenet sweep: same call, wrong solid, no nil.
    @Test("asking for a corner transition does not downgrade the sweep mode")
    func transitionModeKeepsTheRequestedSweepMode() {
        guard let spine = Self.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Could not build the fixtures"); return
        }
        let plain = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile,
                            mode: .fixed(binormal: SIMD3(0, 0, 1))))
        let withTransition = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile,
                            mode: .fixed(binormal: SIMD3(0, 0, 1)), transition: .transformed))
        let frenet = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, transition: .transformed))

        if let plain, let withTransition, let frenet {
            // Transformed is OCCT's own default, so naming it changes nothing.
            #expect(withTransition.volume.isApproximatelyEqual(to: plain.volume, tolerance: 1e-9))
            // And the binormal is still in force, rather than having been dropped for Frenet.
            #expect(!withTransition.volume.isApproximatelyEqual(to: frenet.volume, tolerance: 1e-6),
                    "fixed-binormal sweep collapsed back to Frenet (\(withTransition.volume))")
        } else {
            Issue.record("All three sweeps must build")
        }
    }

    @Test("a mode whose own argument is unusable returns nil instead of another mode's solid")
    func unusableModeArgumentFails() {
        guard let spine = Self.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let straight = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
              let circle = Wire.circle(radius: 2) else {
            Issue.record("Could not build the fixtures"); return
        }
        // A zero-length binormal is not a direction, and is not silently Frenet either.
        #expect(Shape.pipeShell(spine: spine, profile: profile,
                                mode: .fixed(binormal: .zero)) == nil)
        // An auxiliary spine OCCT cannot use fails the sweep rather than being ignored.
        if let sameAsSpine = Wire.line(from: .zero, to: SIMD3(0, 0, 20)) {
            #expect(Shape.pipeShell(spine: straight, profile: circle,
                                    mode: .auxiliary(spine: sameAsSpine)) == nil)
        }
    }

    // MARK: - Reach gained by the unification

    @Test("an auxiliary spine steers a single-profile sweep")
    func auxiliarySpineSteersOneProfile() {
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
              let aux = Wire.line(from: SIMD3(5, 0, 0), to: SIMD3(5, 8, 20)),
              let profile = Wire.circle(radius: 2) else {
            Issue.record("Could not build the fixtures"); return
        }
        let steered = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile, mode: .auxiliary(spine: aux)))
        let plain = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile, mode: .frenet))

        #expect(steered != nil, "the single-profile auxiliary path must build")
        if let steered, let plain {
            #expect(steered.volume.isApproximatelyEqual(to: 251.327629, tolerance: 1e-5))
            #expect(!steered.volume.isApproximatelyEqual(to: plain.volume, tolerance: 1e-9),
                    "the auxiliary spine had no effect")
        }
    }

    @Test("corner transitions reach a multi-section sweep")
    func multiSectionHonoursCornerTransitions() {
        guard let spine = Self.corneredSpine(),
              let start = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 2),
              let end = Wire.circle(origin: SIMD3(15, 0, 20), normal: SIMD3(1, 0, 0), radius: 1) else {
            Issue.record("Could not build the fixtures"); return
        }
        let profiles = [start, end]
        let transformed = Self.fingerprint(
            Shape.pipeShellMultiSection(spine: spine, profiles: profiles, transition: .transformed))
        let rightCorner = Self.fingerprint(
            Shape.pipeShellMultiSection(spine: spine, profiles: profiles, transition: .rightCorner))
        let roundCorner = Self.fingerprint(
            Shape.pipeShellMultiSection(spine: spine, profiles: profiles, transition: .roundCorner))

        #expect(transformed != nil)
        #expect(rightCorner != nil)
        #expect(roundCorner != nil)
        if let transformed, let rightCorner, let roundCorner {
            #expect(!transformed.volume.isApproximatelyEqual(to: rightCorner.volume, tolerance: 1e-6),
                    "rightCorner did not reach the multi-section sweep")
            #expect(!rightCorner.volume.isApproximatelyEqual(to: roundCorner.volume, tolerance: 1e-6),
                    "roundCorner did not reach the multi-section sweep")
            // A rounded corner carries the extra face that rounds it.
            #expect(roundCorner.faces > rightCorner.faces)
        }
    }

    @Test("withContact and withCorrection reach a single-profile sweep")
    func singleProfileHonoursContactAndCorrection() {
        // A profile parked off the spine and tilted away from it, so both flags have work.
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
              let profile = Wire.circle(origin: SIMD3(6, 0, 0), normal: SIMD3(1, 1, 2), radius: 2) else {
            Issue.record("Could not build the fixtures"); return
        }
        let plain = Self.fingerprint(Shape.pipeShell(spine: spine, profile: profile))
        let corrected = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile, withCorrection: true))
        let contacted = Self.fingerprint(
            Shape.pipeShell(spine: spine, profile: profile, withContact: true))

        if let plain, let corrected, let contacted {
            // Rotating the tilted section orthogonal to the spine sweeps a true cylinder:
            // pi * 2^2 * 20. The tilted sweep is thinner.
            #expect(corrected.volume.isApproximatelyEqual(to: 251.327412, tolerance: 1e-5))
            #expect(!plain.volume.isApproximatelyEqual(to: corrected.volume, tolerance: 1e-6),
                    "withCorrection had no effect")
            // Contact translates the section onto the spine, which preserves the volume but
            // not the solid, so compare where it lands rather than how big it is.
            if let plainShape = Shape.pipeShell(spine: spine, profile: profile),
               let contactedShape = Shape.pipeShell(spine: spine, profile: profile, withContact: true) {
                #expect(!plainShape.bounds!.min.x.isApproximatelyEqual(
                            to: contactedShape.bounds!.min.x, tolerance: 1e-6),
                        "withContact had no effect")
            }
            #expect(contacted.volume > 0)
        } else {
            Issue.record("All three sweeps must build")
        }
    }
}

// Not private: Issue598PipeShellFrenetModeTests (same target) reuses this rather than
// reimplementing the same scale-relative tolerance formula a third time.
extension Double {
    func isApproximatelyEqual(to other: Double, tolerance: Double) -> Bool {
        abs(self - other) <= tolerance * Swift.max(1.0, abs(self), abs(other))
    }
}
