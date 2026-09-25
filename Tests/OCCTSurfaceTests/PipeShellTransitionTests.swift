import Testing
import simd

@testable import OCCTSwift

@Suite("Pipe Shell Transition Mode")
struct PipeShellTransitionTests {

    // #766: all three asserted only `result != nil`. `pipeTransformed` swept a circle lying in
    // the XY plane along an L spine that also lies in the XY plane: the profile plane contains
    // the spine tangent, and the kernel returns a "valid" solid of volume 0, which `!= nil`
    // accepted. Its profile now faces along the first leg (normal +X). Each test pins the
    // kernel's volume from BRepOffsetAPI_MakePipeShell (Frenet, the transition, MakeSolid), see
    // Scripts/repro/766-pipe-shell/.
    @Test("Pipe with transformed transition")
    func pipeTransformed() {
        // L-shaped spine (two line segments at right angle)
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let spine = Wire.path([p1, p2, p3])!
        let profile = Wire.circle(origin: .zero, normal: SIMD3(1, 0, 0), radius: 1)!
        let result = Shape.pipeShell(
            spine: spine, profile: profile,
            transition: .transformed, solid: true
        )
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            // pi * 1^2 * 10: the kernel's solid is one leg's worth, recorded as measured.
            #expect(abs((result.volume ?? 0) - 31.415926535897935) < 1e-6)
        }
    }

    @Test("Pipe with right corner transition")
    func pipeRightCorner() {
        // Spine goes along Z first, so default XY-plane circle profile
        // is perpendicular to the spine tangent (required for RightCorner)
        let spine = Wire.path([SIMD3(0, 0, 0), SIMD3(0, 0, 10), SIMD3(0, 10, 10)])!
        let profile = Wire.circle(radius: 2)!
        let result = Shape.pipeShell(
            spine: spine, profile: profile,
            transition: .rightCorner, solid: true
        )
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(abs((result.volume ?? 0) - 251.32741228691418) < 1e-6)
        }
    }

    @Test("Pipe with round corner transition")
    func pipeRoundCorner() {
        // Spine goes along Z first, so default XY-plane circle profile
        // is perpendicular to the spine tangent (required for RoundCorner)
        let spine = Wire.path([SIMD3(0, 0, 0), SIMD3(0, 0, 10), SIMD3(0, 10, 10)])!
        let profile = Wire.circle(radius: 2)!
        let result = Shape.pipeShell(
            spine: spine, profile: profile,
            transition: .roundCorner, solid: true
        )
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            // Less than the right corner's 251.33: the rounded corner cuts the outside of the bend.
            #expect(abs((result.volume ?? 0) - 249.03832602994237) < 1e-6)
        }
    }
}
