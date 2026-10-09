import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_Stretch")
struct GeomFillStretchTests {
    @Test("stretch fill from 4 boundary point arrays")
    func stretchFill() {
        let p1 = [SIMD3(0.0, 0.0, 0.0), SIMD3(5.0, 0.0, 1.0), SIMD3(10.0, 0.0, 0.0)]
        let p2 = [SIMD3(10.0, 0.0, 0.0), SIMD3(10.0, 5.0, 2.0), SIMD3(10.0, 10.0, 0.0)]
        let p3 = [SIMD3(10.0, 10.0, 0.0), SIMD3(5.0, 10.0, 1.0), SIMD3(0.0, 10.0, 0.0)]
        let p4 = [SIMD3(0.0, 10.0, 0.0), SIMD3(0.0, 5.0, 2.0), SIMD3(0.0, 0.0, 0.0)]
        // #766: inside `if let`, `> 0` counts. GeomFill_Stretch on these rows gives 3 x 3 poles;
        // the centre pole is (7.5, 7.5, 3). As with GeomFill_Coons, the rows are read in its own
        // order, so the grid is the kernel's for these inputs rather than the square's, see
        // Scripts/repro/766-geomfill-d/.
        let result = Surface.stretchFill(p1: p1, p2: p2, p3: p3, p4: p4)
        #expect(result != nil)
        if let result {
            #expect(result.nbUPoles == 3)
            #expect(result.nbVPoles == 3)
            #expect(result.poles.count == result.nbUPoles * result.nbVPoles)
            if result.poles.count == 9 {
                #expect(simd_length(result.poles[4] - SIMD3(7.5, 7.5, 3)) < 1e-9)
                #expect(simd_length(result.poles[1] - SIMD3(0, 5, 2)) < 1e-9)
            }
        }
    }

    @Test("isRational for linear stretch")
    func isRational() {
        let p1 = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 0.0, 0.0)]
        let p2 = [SIMD3(1.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0)]
        let p3 = [SIMD3(1.0, 1.0, 0.0), SIMD3(0.0, 1.0, 0.0)]
        let p4 = [SIMD3(0.0, 1.0, 0.0), SIMD3(0.0, 0.0, 0.0)]
        let result = Surface.stretchFill(p1: p1, p2: p2, p3: p3, p4: p4)
        #expect(result != nil)  // #766: a nil result used to pass
        if let result {
            #expect(!result.isRational)
        }
    }
}
