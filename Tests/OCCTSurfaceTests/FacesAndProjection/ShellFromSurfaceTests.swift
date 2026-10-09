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
            #expect(s.surfaceArea! > 0)
        }
    }

    @Test("Shell from plane surface")
    func shellFromPlane() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        let shell = Shape.shell(from: plane, uRange: -5.0...5.0, vRange: -5.0...5.0)
        #expect(shell != nil)
    }
}
