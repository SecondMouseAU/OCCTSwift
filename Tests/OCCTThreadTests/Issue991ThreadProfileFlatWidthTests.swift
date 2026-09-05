import Foundation
import Testing
import simd

@testable import OCCTSwift

// #991: the cutter's local `flatWidth(atDepth:)` closure re-derived, from `spec.profile.segments`,
// something only the profile knows: how much of the pitch its crest and root flats take up. It now
// lives on `ThreadProfile` as `flatWidthFraction(atDepth:)`, and the crest/root classification it
// shares with `hasCrestFlat` and the direct build's crest lookup is one `Segment.isFlat(atDepth:)`
// predicate rather than three spellings of the same comparison.
//
// The expected fractions below come from each form's own standard (ISO-68's P/8 crest and P/4
// root, DIN 513's vertex table, DIN 405's crest land), not from running the accessor.
@Suite("Issue #991: the profile owns its own flat widths")
struct Issue991ThreadProfileFlatWidthTests {

    @Test(
        "flat widths match each form's standard",
        arguments: [
            ("iso60V", ThreadProfile.iso60V(), 1.0 / 8, 1.0 / 4),
            ("whitworth55", ThreadProfile.whitworth55, 1.0 / 6, 1.0 / 6),
            ("acme29", ThreadProfile.acme29, 0.3707, 0.3707),
            ("square", ThreadProfile.square, 0.5, 0.5),
            ("buttress", ThreadProfile.buttress, 0.26, 0.1936),
            // Knuckle is the case a `first(where:)` implementation would get wrong: its crest land
            // is two segments meeting at the tooth centre, and its root land is split across the
            // two ends of the pitch. Both halves have to be summed.
            ("knuckle", ThreadProfile.knuckle, 0.06, 0.06),
        ] as [(String, ThreadProfile, Double, Double)])
    func flatWidthsMatchTheStandard(_ fixture: (String, ThreadProfile, Double, Double)) {
        let (name, profile, crest, root) = fixture
        #expect(
            abs(profile.flatWidthFraction(atDepth: 0) - crest) < 1e-9,
            "\(name) crest: \(profile.flatWidthFraction(atDepth: 0)) != \(crest)")
        #expect(
            abs(profile.flatWidthFraction(atDepth: 1) - root) < 1e-9,
            "\(name) root: \(profile.flatWidthFraction(atDepth: 1)) != \(root)")
    }

    /// A pointed crest has no flat to measure, and `hasCrestFlat` and `flatWidthFraction` have to
    /// agree about that: both read the same `isFlat(atDepth:)` predicate now, so a profile that
    /// answers `false` to one must answer 0 to the other.
    @Test("a pointed crest measures zero and reports no crest flat")
    func pointedCrestIsZero() {
        guard
            let pointed = ThreadProfile(vertices: [
                .init(axial: 0, depth: 1), .init(axial: 0.1, depth: 1),
                .init(axial: 0.5, depth: 0),
                .init(axial: 0.9, depth: 1), .init(axial: 1, depth: 1),
            ])
        else {
            Issue.record("pointed profile rejected")
            return
        }
        #expect(pointed.hasCrestFlat == false)
        #expect(pointed.flatWidthFraction(atDepth: 0) == 0)
        #expect(abs(pointed.flatWidthFraction(atDepth: 1) - 0.2) < 1e-9)
    }

    /// The cutter reads these two numbers to size the groove, so a wrong answer here shows up as a
    /// wrong groove rather than as a compile error. This is the end-to-end half: an internal
    /// thread whose groove is sized from the profile's own flats still cuts material out of a
    /// bore wall and leaves the outer diameter alone.
    @Test("the cut path still sizes its groove from the profile")
    func cutPathStillCuts() {
        let spec = ThreadSpec(form: .square, nominalDiameter: 12, pitch: 2.0)
        // Pre-bored to the MINOR diameter (#1578): see Issue187ScrewThreadTests for why.
        guard let outer = Shape.cylinder(radius: 12, height: 16),
            let bore = Shape.cylinder(radius: spec.minorDiameter / 2, height: 16),
            let block = outer.subtracting(bore)
        else {
            Issue.record("annulus setup failed")
            return
        }
        guard
            let tapped = block.threadedHole(
                axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), spec: spec, depth: 14)
        else {
            Issue.record("threadedHole returned nil")
            return
        }
        #expect(tapped.isValid)
        if let blockVolume = block.volume, let tappedVolume = tapped.volume {
            #expect(tappedVolume < blockVolume)
            #expect(tappedVolume > blockVolume * 0.8)
        }
    }
}
