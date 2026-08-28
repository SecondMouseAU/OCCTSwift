import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Curved")
struct GeomFillCurvedTests {
    @Test("Curved filling from boundaries")
    func curvedFilling() {
        let n = 5
        var b1 = [SIMD3<Double>]()
        var b2 = [SIMD3<Double>]()
        var b3 = [SIMD3<Double>]()
        var b4 = [SIMD3<Double>]()
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            b1.append(SIMD3(t * 10, 0, sin(t * .pi)))
            b2.append(SIMD3(t * 10, 10, sin(t * .pi) + 1))
            b3.append(SIMD3(0, t * 10, sin(t * .pi) * 0.5))
            b4.append(SIMD3(10, t * 10, sin(t * .pi) * 0.5 + 0.5))
        }
        let result = Shape.curvedFilling(boundary1: b1, boundary2: b2, boundary3: b3, boundary4: b4)
        #expect(result != nil)
        if let result = result {
            #expect(result.poles.count > 0)
        }
    }
}
