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
        // #766: the inputs were behind `if let`, and `errorOnSurface >= 0` passed any positive
        // error. BRepFill_Pipe on the same wires sweeps the 2 pi r h = 1570.796 cylinder wall
        // and reports ErrorOnSurface exactly 0 for a straight spine, see
        // Scripts/repro/766-pipe-findsurface-bspline/.
        #expect(spine != nil && profile != nil)
        if let spine, let profile {
            let result = Shape.pipeSweep(spine: spine, profile: profile)
            #expect(result != nil)
            if let r = result {
                #expect(r.shape.isValid)
                #expect(r.errorOnSurface == 0)
                #expect(abs((r.shape.surfaceArea ?? 0) - 1570.7963267948967) < 1e-6)
            }
        }
    }
}
