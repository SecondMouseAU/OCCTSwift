import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.137 Ch2: Surface type predicates + continuity class

@Suite("v0.137 Surface type predicates")
struct SurfaceTypePredicatesTests {
    @Test("Cylinder predicates")
    func cylinder() {
        guard let s = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("cyl nil")
            return
        }
        #expect(s.isCylinder)
        #expect(!s.isPlane)
        #expect(!s.isTorus)
        #expect(!s.isSphere)
    }

    @Test("Torus predicates")
    func torus() {
        guard
            let s = Surface.torus(
                origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
                majorRadius: 20, minorRadius: 5)
        else {
            Issue.record("torus nil")
            return
        }
        #expect(s.isTorus)
        #expect(!s.isCylinder)
    }

    @Test("Analytic surfaces are at least C2 continuous")
    func analyticContinuity() {
        guard let s = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("cyl nil")
            return
        }
        let c = s.continuityClass
        #expect(c == .cN || c == .c3 || c == .c2)
    }
}
