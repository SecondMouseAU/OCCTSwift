import Testing
import simd

@testable import OCCTSwift

@Suite("Plate GlobalTranslation Constraint")
struct PlateGlobalTranslationTests {

    // #766: the load functions return true whatever Plate_Plate does with the constraint, so a
    // test that checks only that Bool passes a constraint that was never loaded. Each test here
    // now solves and evaluates, pinned to Plate_Plate's own answer for the same constraints
    // (SolveTI(4, 1.0)), see Scripts/repro/766-plate-solver-surface/.
    @Test func loadGlobalTranslation() {
        let plate = PlateSolver()
        let uvs = [SIMD2(0.0, 0.0), SIMD2(1.0, 0.0), SIMD2(0.0, 1.0)]
        #expect(plate.loadGlobalTranslation(uvPoints: uvs))
        // The three uv points must share one translation: pin one, and the others follow it.
        plate.loadPinpoint(u: 0, v: 0, position: SIMD3(0, 0, 1))
        #expect(plate.solve())
        #expect(simd_length(plate.evaluate(u: 1, v: 0) - SIMD3(0, 0, 1)) < 1e-9)
        #expect(simd_length(plate.evaluate(u: 0, v: 1) - SIMD3(0, 0, 1)) < 1e-9)
    }

    @Test func solveWithGlobalTranslation() {
        let plate = PlateSolver()
        // Add some pinpoint constraints first
        plate.loadPinpoint(u: 0, v: 0, position: SIMD3(0, 0, 1))
        plate.loadPinpoint(u: 1, v: 0, position: SIMD3(0, 0, 1))
        plate.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 0, 1))
        let solved = plate.solve()
        // Was `solved || !solved`. Three equal pinpoints solve, to a surface at z = 1.
        #expect(solved)
        #expect(abs(plate.evaluate(u: 0.5, v: 0.5).z - 1.0000002402910662) < 1e-9)
    }
}
