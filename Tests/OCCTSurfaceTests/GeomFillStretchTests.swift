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
        if let result = Surface.stretchFill(p1: p1, p2: p2, p3: p3, p4: p4) {
            #expect(result.nbUPoles > 0)
            #expect(result.nbVPoles > 0)
            #expect(result.poles.count == result.nbUPoles * result.nbVPoles)
        }
    }

    @Test("isRational for linear stretch")
    func isRational() {
        let p1 = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 0.0, 0.0)]
        let p2 = [SIMD3(1.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0)]
        let p3 = [SIMD3(1.0, 1.0, 0.0), SIMD3(0.0, 1.0, 0.0)]
        let p4 = [SIMD3(0.0, 1.0, 0.0), SIMD3(0.0, 0.0, 0.0)]
        if let result = Surface.stretchFill(p1: p1, p2: p2, p3: p3, p4: p4) {
            #expect(!result.isRational)
        }
    }
}
