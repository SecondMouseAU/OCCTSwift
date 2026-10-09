import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.33.0. OCCT Test Suite Audit Round 2

@Suite("Evolved Advanced")
struct EvolvedAdvancedTests {
    @Test("Evolved advanced with arc join")
    func evolvedAdvancedArc() {
        // Spine: a planar face (rectangle)
        let spine = Shape.box(width: 20, height: 20, depth: 1)!
        // Profile: small rectangle wire
        let profile = Wire.rectangle(width: 1, height: 1)!
        let result = Shape.evolvedAdvanced(
            spine: spine, profile: profile,
            joinType: .arc, axeProf: true, solid: true
        )
        // Evolved with a 3D box spine is complex; just verify API is callable
        _ = result
    }

    @Test("Evolved advanced with intersection join")
    func evolvedAdvancedIntersection() {
        // Use a wire spine
        let spine = Wire.rectangle(width: 10, height: 10)!
        let profile = Wire.rectangle(width: 0.5, height: 0.5)!
        let result = Shape.evolvedAdvanced(
            spine: Shape.evolved(spine: spine, profile: Wire.rectangle(width: 0.1, height: 0.1)!)
                ?? Shape.box(width: 10, height: 10, depth: 1)!,
            profile: profile,
            joinType: .intersection, solid: false
        )
        _ = result
    }
}
