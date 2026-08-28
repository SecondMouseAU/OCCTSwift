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
        if let result = result {
            #expect(result.poles.count > 0)
            #expect(result.nbU > 0)
            #expect(result.nbV > 0)
        }
    }
}
