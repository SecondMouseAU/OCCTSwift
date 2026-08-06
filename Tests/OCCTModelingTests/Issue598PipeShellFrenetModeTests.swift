// #598: `occtPipeShellSetMode` (`OCCTBridge_Modeling.mm`) passed the opposite boolean to
// `BRepOffsetAPI_MakePipeShell::SetMode`, whose parameter is `IsFrenet`: `.frenet` built a
// corrected-Frenet sweep and `.correctedFrenet` built a plain Frenet one, straight through every
// public `PipeSweepMode` caller (`.frenet` is the default on all three `Shape.pipeShell*` spellings).
//
// These tests pin the fix against an *independent* oracle rather than a hand-picked literal:
// `PipeShellBuilder.setFrenet(_:)` calls `BRepFill_PipeShell::Set(frenet)` directly and was never
// wrong (a separate code path from the enum-driven bridge function this issue fixes), so a match
// against it is real cross-checking, not two copies of the same mistake agreeing with each other.

import Testing
import Foundation
@testable import OCCTSwift

@Suite("PipeSweepMode Frenet/correctedFrenet were swapped (#598)")
struct Issue598PipeShellFrenetModeTests {

    /// Same fixture Issue503PipeShellTests.curvedSpine() uses: curved enough that Frenet and
    /// corrected Frenet disagree, which a straight spine cannot show (see
    /// `theTwoModesAgreeOnASpineWithNoTorsion` below).
    static func curvedSpine() -> Wire? {
        Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 5, 0), SIMD3(20, -5, 10), SIMD3(30, 0, 10)])
    }

    /// Builds the same single-profile, transformed-transition, solid sweep as
    /// `Shape.pipeShell(spine:profile:mode:)`'s defaults, but through `PipeShellBuilder`
    /// (`BRepFill_PipeShell::Set(Standard_Boolean)` directly) instead of the `PipeSweepMode`
    /// enum this issue's fix touches. An independent path to the same OCCT trihedron law.
    static func groundTruth(spine: Wire, profile: Wire, frenet: Bool) -> Shape? {
        guard let spineShape = Shape.fromWire(spine), let profileShape = Shape.fromWire(profile),
              let builder = PipeShellBuilder(spine: spineShape) else { return nil }
        builder.setFrenet(frenet)
        builder.add(profile: profileShape)
        builder.setTransition(.modified) // BRepBuilderAPI_Transformed, pipeShell's own default
        guard builder.build() else { return nil }
        builder.makeSolid()
        return builder.shape
    }

    static func isClose(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
        abs(a - b) <= tolerance * Swift.max(1.0, abs(a), abs(b))
    }

    @Test(".frenet matches BRepFill_PipeShell::Set(true), the actual Frenet trihedron")
    func frenetMatchesTrueFrenet() {
        guard let spine = Self.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
              let viaEnum = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet),
              let vEnum = viaEnum.volume, let vFrenet = trueFrenet.volume,
              let vCorrected = trueCorrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }

        // The oracle values themselves must actually disagree on this spine, or a match against
        // either one would be meaningless.
        #expect(!Self.isClose(vFrenet, vCorrected), "oracle Frenet and corrected Frenet must differ")

        #expect(Self.isClose(vEnum, vFrenet),
                ".frenet (\(vEnum)) should match the true Frenet sweep (\(vFrenet))")
        #expect(!Self.isClose(vEnum, vCorrected),
                ".frenet (\(vEnum)) must not match the corrected-Frenet sweep (\(vCorrected))")
        #expect(vEnum.isApproximatelyEqualLiteral(177.347557))
    }

    @Test(".correctedFrenet matches BRepFill_PipeShell::Set(false), the actual corrected Frenet trihedron")
    func correctedFrenetMatchesTrueCorrectedFrenet() {
        guard let spine = Self.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let trueCorrected = Self.groundTruth(spine: spine, profile: profile, frenet: false),
              let viaEnum = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet),
              let vEnum = viaEnum.volume, let vFrenet = trueFrenet.volume,
              let vCorrected = trueCorrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }

        #expect(Self.isClose(vEnum, vCorrected),
                ".correctedFrenet (\(vEnum)) should match the true corrected-Frenet sweep (\(vCorrected))")
        #expect(!Self.isClose(vEnum, vFrenet),
                ".correctedFrenet (\(vEnum)) must not match the plain Frenet sweep (\(vFrenet))")
        #expect(vEnum.isApproximatelyEqualLiteral(180.286724))
    }

    @Test("the multi-section spelling honours the same, now-corrected mapping")
    func multiSectionSpellingAlsoFixed() {
        guard let spine = Self.curvedSpine(), let profile = Wire.rectangle(width: 5, height: 3),
              let trueFrenet = Self.groundTruth(spine: spine, profile: profile, frenet: true),
              let viaMulti = Shape.pipeShellMultiSection(spine: spine, profiles: [profile], mode: .frenet),
              let vMulti = viaMulti.volume, let vFrenet = trueFrenet.volume else {
            Issue.record("Could not build the fixtures"); return
        }
        #expect(Self.isClose(vMulti, vFrenet),
                "pipeShellMultiSection(mode: .frenet) (\(vMulti)) should match true Frenet (\(vFrenet))")
    }

    /// The blast radius this issue measured: a spine with no torsion cannot distinguish the two
    /// trihedron laws, so the swap was silent there and only wrong on a spine with genuine
    /// curvature/torsion (the fixture every other test in this file uses).
    @Test("the two modes agree on a spine with no torsion, so the swap was silent there")
    func theTwoModesAgreeOnASpineWithNoTorsion() {
        guard let straight = Wire.line(from: .zero, to: SIMD3(0, 0, 20)),
              let profile = Wire.circle(radius: 2),
              let frenet = Shape.pipeShell(spine: straight, profile: profile, mode: .frenet),
              let corrected = Shape.pipeShell(spine: straight, profile: profile, mode: .correctedFrenet),
              let vFrenet = frenet.volume, let vCorrected = corrected.volume else {
            Issue.record("Could not build the fixtures"); return
        }
        #expect(Self.isClose(vFrenet, vCorrected),
                "a straight spine has no torsion to disagree about: \(vFrenet) vs \(vCorrected)")
    }
}

private extension Double {
    func isApproximatelyEqualLiteral(_ other: Double, tolerance: Double = 1e-5) -> Bool {
        abs(self - other) <= tolerance * Swift.max(1.0, abs(self), abs(other))
    }
}
