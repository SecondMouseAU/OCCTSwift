import Testing
import simd

@testable import OCCTSwift

@Suite("Plate Constraint Extension Tests", .serialized)
struct PlateConstraintExtTests {

    @Test func planeConstraint() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        let ok = solver.loadPlaneConstraint(
            u: 0.5, v: 0.5,
            planePoint: .zero,
            planeNormal: SIMD3(0, 0, 1))
        #expect(ok)
    }

    @Test func lineConstraint() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        let ok = solver.loadLineConstraint(
            u: 0.5, v: 0.5,
            linePoint: .zero,
            lineDirection: SIMD3(1, 0, 0))
        #expect(ok)
    }

    // freeG1Constraint test disabled. Plate_FreeGtoCConstraint causes SEGV in OCCT 8.0.0-rc4
    // when loading generated LSCs into solver. The bridge function works but is unsafe to test.
}
