import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Coons")
struct GeomFillCoonsTests {
    @Test("Coons filling from boundaries")
    func coonsFilling() {
        let n = 5
        var b1 = [SIMD3<Double>]()
        var b2 = [SIMD3<Double>]()
        var b3 = [SIMD3<Double>]()
        var b4 = [SIMD3<Double>]()
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            b1.append(SIMD3(t * 10, 0, 0))
            b2.append(SIMD3(t * 10, 10, 0))
            b3.append(SIMD3(0, t * 10, 0))
            b4.append(SIMD3(10, t * 10, 0))
        }
        let result = Shape.coonsFilling(boundary1: b1, boundary2: b2, boundary3: b3, boundary4: b4)
        #expect(result != nil)
        // #766: `> 0` passed any grid. GeomFill_Coons on the same four rows gives 5 x 5 poles.
        // The rows are passed as (bottom, top, left, right), not chained head to tail around the
        // loop as GeomFill_Coons reads them, so the interior poles are not the flat square's:
        // the pinned values are the kernel's own for these inputs, see Scripts/repro/766-geomfill-a/.
        if let result = result {
            #expect(result.nbU == 5)
            #expect(result.nbV == 5)
            #expect(result.poles.count == 25)
            if result.poles.count == 25 {
                #expect(simd_length(result.poles[0] - SIMD3(0, 10, 0)) < 1e-9)
                #expect(simd_length(result.poles[8] - SIMD3(-2.5, 2.5, 0)) < 1e-9)
                #expect(simd_length(result.poles[24] - SIMD3(10, 10, 0)) < 1e-9)
            }
        }
    }
}
