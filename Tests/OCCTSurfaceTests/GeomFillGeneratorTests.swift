import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill Generator")
struct GeomFillGeneratorTests {
    @Test func twoCircles() {
        let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 1.0)
        let c2 = Curve3D.circle(center: SIMD3(0, 0, 2), normal: SIMD3(0, 0, 1), radius: 1.5)
        if let c1 = c1, let c2 = c2 {
            let surf = Surface.generatedFromSections(curves: [c1, c2])
            #expect(surf != nil)
        }
    }

    @Test func threeSections() {
        let c1 = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 1.0)
        let c2 = Curve3D.circle(center: SIMD3(0, 0, 2), normal: SIMD3(0, 0, 1), radius: 1.5)
        let c3 = Curve3D.circle(center: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1), radius: 0.5)
        if let c1 = c1, let c2 = c2, let c3 = c3 {
            let surf = Surface.generatedFromSections(curves: [c1, c2, c3])
            #expect(surf != nil)
        }
    }
}
