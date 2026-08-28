import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill Pipe Tests")
struct BRepFillPipeTests {
    @Test("Pipe sweep with error metric")
    func pipeSweep() {
        // Straight spine
        let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 50))
        let profile = Wire.circle(radius: 5)
        if let spine, let profile {
            let result = Shape.pipeSweep(spine: spine, profile: profile)
            #expect(result != nil)
            if let r = result {
                #expect(r.shape.isValid)
                #expect(r.errorOnSurface >= 0)
            }
        }
    }
}
