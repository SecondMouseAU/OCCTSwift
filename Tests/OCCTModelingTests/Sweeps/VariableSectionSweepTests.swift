import Testing

@testable import OCCTSwift

// MARK: - v0.21.0 Variable-Section Sweep Tests

@Suite("Variable-Section Sweep Tests")
struct VariableSectionSweepTests {
    @Test("Pipe shell with constant law")
    func pipeShellConstantLaw() throws {
        // Straight spine
        let spine = try #require(Wire.line(from: .zero, to: SIMD3(0, 0, 20)))
        // Circular profile
        let profile = try #require(Wire.circle(radius: 5))
        // Constant scaling law (no change)
        let law = try #require(LawFunction.constant(1.0, from: 0, to: 1))

        let pipe = try #require(Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law))
        // A constant law of 1 is the plain pipe: pi * 5^2 * 20 = 1570.796... (kernel.6 measured
        // 1570.7959, the swept surface is an approximation), a lateral face and two caps.
        #expect(abs((pipe.volume ?? -1) - Double.pi * 25.0 * 20.0) < 1e-2)
        #expect(pipe.faces().count == 3)
        let bounds = try #require(pipe.boundingBox)
        #expect(abs(bounds.min.z) < 1e-3 && abs(bounds.max.z - 20.0) < 1e-3)
    }

    @Test("Pipe shell with linear tapering law")
    func pipeShellLinearLaw() throws {
        // Straight spine
        let spine = try #require(Wire.line(from: .zero, to: SIMD3(0, 0, 30)))
        // Circular profile
        let profile = try #require(Wire.circle(radius: 5))
        // Linear tapering: starts at 1x, ends at 2x
        let law = try #require(LawFunction.linear(from: 1.0, to: 2.0))

        let pipe = try #require(Shape.pipeShellWithLaw(spine: spine, profile: profile, law: law))
        // Radius 5 growing to 10 over 30 is a cone frustum: pi h / 3 (r1^2 + r1 r2 + r2^2) =
        // pi * 10 * 175 = 5497.787... (kernel.6 measured 5497.7857). A constant-law pipe of the
        // same length is pi * 25 * 30 = 2356.19, so the taper is what made the extra volume.
        #expect(abs((pipe.volume ?? -1) - Double.pi * 30.0 / 3.0 * 175.0) < 0.05)
        #expect(pipe.faces().count == 3)
    }
}
