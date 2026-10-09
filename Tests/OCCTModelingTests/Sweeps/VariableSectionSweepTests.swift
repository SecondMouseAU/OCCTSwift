import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.21.0 Variable-Section Sweep Tests

@Suite("Variable-Section Sweep Tests")
struct VariableSectionSweepTests {
    @Test("Pipe shell with constant law")
    func pipeShellConstantLaw() {
        // Straight spine
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 20)) else {
            Issue.record("Could not create spine")
            return
        }
        // Circular profile
        guard let profile = Wire.circle(radius: 5) else {
            Issue.record("Could not create profile")
            return
        }
        // Constant scaling law (no change)
        guard let law = LawFunction.constant(1.0, from: 0, to: 1) else {
            Issue.record("Could not create law")
            return
        }

        let pipe = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law)
        #expect(pipe != nil)
        if let pipe = pipe {
            #expect((pipe.volume ?? 0) > 0)
        }
    }

    @Test("Pipe shell with linear tapering law")
    func pipeShellLinearLaw() {
        // Straight spine
        guard let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 30)) else {
            Issue.record("Could not create spine")
            return
        }
        // Circular profile
        guard let profile = Wire.circle(radius: 5) else {
            Issue.record("Could not create profile")
            return
        }
        // Linear tapering: starts at 1x, ends at 2x
        guard let law = LawFunction.linear(from: 1.0, to: 2.0) else {
            Issue.record("Could not create law")
            return
        }

        let pipe = Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law)
        #expect(pipe != nil)
        if let pipe = pipe {
            #expect((pipe.volume ?? 0) > 0)
        }
    }
}
