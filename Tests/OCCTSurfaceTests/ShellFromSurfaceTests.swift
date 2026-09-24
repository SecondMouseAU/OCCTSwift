import Testing
import simd

@testable import OCCTSwift

@Suite("Shell from Surface")
struct ShellFromSurfaceTests {
    @Test("Shell from cylinder surface")
    func shellFromCylinder() {
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        let shell = Shape.shell(from: cyl, uRange: 0.0...(2 * Double.pi), vRange: 0.0...10.0)
        #expect(shell != nil)
        if let s = shell {
            // #766: was `surfaceArea! > 0` (force unwrap in #expect, any area). 2 pi * 5 * 10.
            #expect(abs((s.surfaceArea ?? 0) - 314.15926535897933) < 1e-9)
        }
    }

    @Test("Shell from plane surface")
    func shellFromPlane() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let shell = Shape.shell(from: plane, uRange: -5.0...5.0, vRange: -5.0...5.0)
        #expect(shell != nil)
        // #766: was non-nil only. BRepBuilderAPI_MakeShell gives the 10 x 10 square.
        #expect(abs((shell?.surfaceArea ?? 0) - 100) < 1e-9)
    }
}
