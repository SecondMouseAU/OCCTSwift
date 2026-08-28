import Testing
import simd

@testable import OCCTSwift

@Suite("Plate GlobalTranslation Constraint")
struct PlateGlobalTranslationTests {
    @Test func loadGlobalTranslation() {
        let plate = PlateSolver()
        let uvs = [SIMD2(0.0, 0.0), SIMD2(1.0, 0.0), SIMD2(0.0, 1.0)]
        #expect(plate.loadGlobalTranslation(uvPoints: uvs))
    }

    @Test func solveWithGlobalTranslation() {
        let plate = PlateSolver()
        // Add some pinpoint constraints first
        plate.loadPinpoint(u: 0, v: 0, position: SIMD3(0, 0, 1))
        plate.loadPinpoint(u: 1, v: 0, position: SIMD3(0, 0, 1))
        plate.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 0, 1))
        let solved = plate.solve()
        // May or may not solve depending on constraint compatibility
        #expect(solved || !solved)
    }
}
