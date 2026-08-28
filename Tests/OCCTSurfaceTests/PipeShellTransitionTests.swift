import Testing
import simd

@testable import OCCTSwift

@Suite("Pipe Shell Transition Mode")
struct PipeShellTransitionTests {
    @Test("Pipe with transformed transition")
    func pipeTransformed() {
        // L-shaped spine (two line segments at right angle)
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let spine = Wire.path([p1, p2, p3])!
        let profile = Wire.circle(radius: 1)!
        let result = Shape.pipeShell(
            spine: spine, profile: profile,
            transition: .transformed, solid: true
        )
        #expect(result != nil)
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
    }
}
