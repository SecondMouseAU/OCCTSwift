import Testing

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
        // Six vertices make five segments: root flat, flank, crest flat, flank, root flat. The
        // order matters (a crest flat is the middle one), so pin the sequence, not a count.
        #expect(p.segments.map(\.kind) == [.flat, .flank, .flat, .flank, .flat])
        // The control, in the same test so the predicate cannot be a constant: the pointed
        // triangle used by pointedProfileRejected has no crest flat and is not buildable.
        if let pointed = ThreadProfile(vertices: [
            .init(axial: 0.0, depth: 1), .init(axial: 0.5, depth: 0), .init(axial: 1.0, depth: 1),
        ]) {
            #expect(!pointed.hasCrestFlat)
            #expect(!pointed.supportsSmoothRodBuild)
        } else {
            Issue.record("pointed profile")
        }
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
        // The windows `0 < v < stock` and `v > 0.25 * stock` passed any volume between 340 and
        // 1357, an over-cut of 40% included. Pin it against an independent construction: a
        // helicoid's volume is length times the mean over one pitch of pi * r(u)^2, with r
        // running 3 -> 3 (root flat, 0.30 of the pitch), 3 -> 6 and back (flanks, 0.40, mean
        // r^2 = 21), 6 (crest flat, 0.30). That is 12 * pi * 21.9 = 825.6; the kernel measures
        // 825.27, 0.04% below it.
        let expectedVol = length * Double.pi * (0.30 * 9 + 0.40 * 21 + 0.30 * 36)
        // Measured 7 faces; hundreds of facets would mean the analytic build was lost.
        #expect(worm.faces().count == 7)
        guard let v = worm.volume else {
            Issue.record("worm has no volume")
            return
        }
        #expect(abs(v - expectedVol) < 1.0)
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
        // The control: with the same diameter, pitch, cut depth and length, a buildable profile
        // does build, so the nil above is the profile's doing and not the other arguments'.
        if let worm = Self.wormProfile() {
            #expect(
                Shape.threadedRod(
                    customProfile: worm, nominalDiameter: 12,
                    pitch: 4, cutDepth: 3, length: 12) != nil)
        } else {
            Issue.record("worm profile")
        }
    }
}
