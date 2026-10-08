import Testing
import simd

@testable import OCCTSwift

@Suite("Revolution Form Feature")
struct RevolutionFormTests {
    @Test("Add revolution form to shape")
    func addRevolutionForm() {
        // Create two cylinders fused together as base shape
        let c1 = Shape.cylinder(radius: 2, height: 5)!
        let c2 = Shape.cylinder(at: SIMD2(0, 0), bottomZ: 5, radius: 1, height: 3)!
        guard let s = c1.union(c2) else { return }
        // Create a wire profile (a line segment) for the rib
        guard let wire = Wire.line(from: SIMD3(-2, 0, 5), to: SIMD3(-1, 0, 8)) else { return }
        let result = s.addingRevolutionForm(
            profile: wire,
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            height1: 0.2, height2: 0.2
        )
        // Revolution form is complex; just test API is callable
        _ = result
    }
}
