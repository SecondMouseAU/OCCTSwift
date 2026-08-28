import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Approx SameParameter Tests")
struct ApproxSameParameterTests {
    @Test("same parameter on line/plane")
    func sameParamLinePlane() {
        if let line3d = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let line2d = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
            let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        {
            let result = line3d.checkSameParameter(curve2D: line2d, surface: plane)
            if let r = result {
                #expect(r.isSameParameter)
            }
        }
    }
}
