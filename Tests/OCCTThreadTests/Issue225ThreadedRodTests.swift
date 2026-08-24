import Testing
import simd

@testable import OCCTSwift

/// Issue #225: building a smooth worm/screw from a custom radial profile.
///
/// The boolean route the issue tried, `helicalSweep` a profile, then `union`/`subtract` with a
/// coaxial cylinder, is invalid (union) / collapses to zero (subtract) and is *not* the supported
/// path. `Shape.threadedRod(customProfile:)` composes the helicoid with the core directly (no
/// boolean), yielding a valid, analytic solid. These tests lock that in.
@Suite("Issue225, threadedRod from a custom profile")
struct Issue225ThreadedRodTests {

    /// A custom symmetric trapezoidal worm tooth: root radius 3, crest radius 6, pitch 4.
    static func wormProfile() -> ThreadProfile? {
        ThreadProfile(vertices: [
            .init(axial: 0.00, depth: 1),
            .init(axial: 0.15, depth: 1),  // root half-flat
            .init(axial: 0.35, depth: 0),  // flank → crest
            .init(axial: 0.65, depth: 0),  // crest flat
            .init(axial: 0.85, depth: 1),  // flank → root
            .init(axial: 1.00, depth: 1),
        ])
    }

    @Test("custom worm profile is smooth-rod-buildable")
    func profilePredicate() {
        guard let p = Self.wormProfile() else {
            Issue.record("profile")
            return
        }
        #expect(p.hasCrestFlat)
        #expect(p.supportsSmoothRodBuild)
        #expect(p.segments.filter { $0.kind == .flank }.count == 2)
    }

    @Test("threadedRod builds a valid, analytic worm with no boolean")
    func wormIsValidAndAnalytic() {
        guard let p = Self.wormProfile() else {
            Issue.record("profile")
            return
        }
        let majorR = 6.0
        let pitch = 4.0
        let cutDepth = 3.0
        let length = 12.0
        guard
            let worm = Shape.threadedRod(
                customProfile: p, nominalDiameter: 2 * majorR,
                pitch: pitch, cutDepth: cutDepth, length: length)
        else {
            Issue.record("threadedRod returned nil")
            return
        }
        #expect(worm.isValidSolid)  // valid (the issue's whole ask)
        if let v = worm.volume {
            let stockVol = Double.pi * majorR * majorR * length
            #expect(v > 0)  // not collapsed
            #expect(v < stockVol)  // material removed
            #expect(v > stockVol * 0.25)  // but not over-cut
        }
        #expect(worm.faces().count < 60)  // analytic loft, not 100s of facets
    }

    @Test("pointed (no crest flat) custom profile is rejected, not silently bad")
    func pointedProfileRejected() {
        // A triangular ridge like the issue's `rib`: pointed crest, no crest flat.
        guard
            let pointed = ThreadProfile(vertices: [
                .init(axial: 0.0, depth: 1),
                .init(axial: 0.5, depth: 0),
                .init(axial: 1.0, depth: 1),
            ])
        else {
            Issue.record("profile")
            return
        }
        #expect(!pointed.supportsSmoothRodBuild)
        // threadedRod returns nil rather than an invalid boolean result.
        #expect(
            Shape.threadedRod(
                customProfile: pointed, nominalDiameter: 12,
                pitch: 4, cutDepth: 3, length: 12) == nil)
    }
}
