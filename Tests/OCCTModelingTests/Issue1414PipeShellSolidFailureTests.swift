// #1414: occtPipeShellFinish (OCCTBridge_Internal.h) used to re-test IsDone() after calling
// BRepOffsetAPI_MakePipeShell::MakeSolid(), which never touches Done()/NotDone() at all, so
// the re-test was always true once Build() had already succeeded, regardless of whether
// MakeSolid() itself closed the shell into a solid. BRepFill_PipeShell::MakeSolid() (the
// class MakePipeShell wraps) genuinely returns false when the swept shell isn't already
// closed and its end profile isn't a closed wire, since there's then no loop to cap: an
// unclosed profile swept along an open spine is exactly that case. Before the fix, a
// solid:true request against that input silently returned the open shell Build() produced,
// non-nil, with no way for a caller to tell it apart from a genuine solid.

import Testing
import simd

@testable import OCCTSwift

@Suite("Pipe shell MakeSolid() return value (#1414)")
struct Issue1414PipeShellSolidFailureTests {

    /// An open, 3-edge "C" profile: not a closed loop, so BRepFill_PipeShell::MakeSolid()
    /// has no end wire it could ever cap. Swept along a straight (non-periodic) spine, the
    /// resulting shell is open, and the only way to close it (matching the profile's own
    /// closed-ness at each end) is unreachable by construction.
    static func openProfile() -> Wire? {
        Wire.path(
            [
                SIMD3(2, 0, 0),
                SIMD3(2, 2, 0),
                SIMD3(-2, 2, 0),
                SIMD3(-2, 0, 0),
            ], closed: false)
    }

    static func straightSpine() -> Wire? {
        Wire.line(from: .zero, to: SIMD3(0, 0, 20))
    }

    @Test("solid:true with an unclosed profile refuses rather than returning an open shell")
    func unclosedProfileSolidRequestRefuses() {
        guard let spine = Self.straightSpine(), let profile = Self.openProfile() else {
            Issue.record("Could not build the fixtures")
            return
        }
        #expect(profile.curveInfo?.isClosed == false)

        // Ground truth: solid:false with the same input DOES build (an open shell is exactly
        // what an unclosed-profile sweep can honestly produce), so this isn't a fixture that
        // fails to sweep at all, it's specifically a solid:true request that cannot be honored.
        let shell = Shape.pipeShellMultiSection(
            spine: spine, profiles: [profile], mode: .frenet, solid: false)
        #expect(shell != nil, "the shell-only sweep should succeed")
        if let shell {
            #expect(shell.shapeType == .shell)
        }

        let solidRequest = Shape.pipeShellMultiSection(
            spine: spine, profiles: [profile], mode: .frenet, solid: true)
        #expect(
            solidRequest == nil,
            "a solid:true request that MakeSolid() cannot honor must be refused, not answered with the open shell"
        )
    }

    /// Same defect, the other call site: OCCTShapeCreatePipeShellWithLaw shares
    /// occtPipeShellFinish with the Add()-based sweep above.
    @Test("solid:true with an unclosed profile refuses via the law-function sweep too")
    func unclosedProfileSolidRequestRefusesWithLaw() {
        guard let spine = Self.straightSpine(), let profile = Self.openProfile(),
            let law = LawFunction.constant(1.0, from: 0, to: 1)
        else {
            Issue.record("Could not build the fixtures")
            return
        }

        let shell = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law, solid: false)
        #expect(shell != nil, "the shell-only sweep should succeed")

        let solidRequest = Shape.pipeShellWithLaw(
            spine: spine, profile: profile, law: law, solid: true)
        #expect(
            solidRequest == nil,
            "a solid:true request that MakeSolid() cannot honor must be refused, not answered with the open shell"
        )
    }

    /// Control: a closed profile on the same spine legitimately produces a solid, so the fix
    /// isn't just "solid:true always fails now".
    @Test("solid:true with a closed profile still builds a real solid")
    func closedProfileSolidRequestStillSucceeds() {
        guard let spine = Self.straightSpine(), let profile = Wire.circle(radius: 3) else {
            Issue.record("Could not build the fixtures")
            return
        }
        let solid = Shape.pipeShellMultiSection(
            spine: spine, profiles: [profile], mode: .frenet, solid: true)
        #expect(solid != nil)
        if let solid {
            #expect(solid.shapeType == .solid)
        }
    }
}
