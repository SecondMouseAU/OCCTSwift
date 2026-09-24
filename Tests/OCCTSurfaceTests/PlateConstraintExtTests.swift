import Testing
import simd

@testable import OCCTSwift

@Suite("Plate Constraint Extension Tests", .serialized)
struct PlateConstraintExtTests {

    // #766: the load functions return true whatever Plate_Plate does with the constraint, so a
    // test that checks only that Bool passes a constraint that was never loaded. Each test here
    // now solves and evaluates, pinned to Plate_Plate's own answer for the same constraints
    // (SolveTI(4, 1.0)), see Scripts/repro/766-plate-solver-surface/.
    // The plane and the line are placed at z = 1, off the pinpoints' z = 0, so the constraint
    // is visible in the solution (at z = 0 it would hold with or without being loaded).

    @Test func planeConstraint() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        let ok = solver.loadPlaneConstraint(
            u: 0.5, v: 0.5,
            planePoint: SIMD3(0, 0, 1),
            planeNormal: SIMD3(0, 0, 1))
        #expect(ok)
        #expect(solver.solve())
        // F(0.5, 0.5) lands on the plane z = 1.
        #expect(abs(solver.evaluate(u: 0.5, v: 0.5).z - 1) < 1e-9)
    }

    @Test func lineConstraint() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        let ok = solver.loadLineConstraint(
            u: 0.5, v: 0.5,
            linePoint: SIMD3(0, 0, 1),
            lineDirection: SIMD3(1, 0, 0))
        #expect(ok)
        #expect(solver.solve())
        // F(0.5, 0.5) lands on the line y = 0, z = 1.
        let p = solver.evaluate(u: 0.5, v: 0.5)
        #expect(abs(p.y) < 1e-9 && abs(p.z - 1) < 1e-9)
    }

    // freeG1Constraint test disabled. Plate_FreeGtoCConstraint causes SEGV in OCCT 8.0.0-rc4
    // when loading generated LSCs into solver. The bridge function works but is unsafe to test.
}
