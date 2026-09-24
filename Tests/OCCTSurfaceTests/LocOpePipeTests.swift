import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.48.0: Comprehensive Local Operations, Validation, Fixing, Extrema

@Suite("LocOpe Pipe Tests")
struct LocOpePipeTests {
    @Test("Pipe sweep along wire spine")
    func pipeSweep() throws {
        // #766: the profile used to be `Wire.rectangle` in the XY plane, which contains the X
        // spine, so LocOpe_Pipe swept it along itself and returned a zero-volume solid that
        // BRepCheck rejects; `result != nil` accepted it. The 2 x 2 profile now stands in the YZ
        // plane, across the spine, and the kernel builds the 2 x 2 x 10 prism: volume 40, area 88
        // (LocOpe_Pipe, Scripts/repro/766-join-local-loft/).
        let profileWire = Wire.path(
            [SIMD3(0, -1, -1), SIMD3(0, 1, -1), SIMD3(0, 1, 1), SIMD3(0, -1, 1)], closed: true)
        let profileFace = profileWire.flatMap { Shape.face(from: $0) }
        let spine = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        #expect(profileFace != nil)
        #expect(spine != nil)
        guard let profileFace, let spine else { return }
        let result = profileFace.localPipe(along: spine)
        #expect(result != nil, "Pipe sweep should produce a shape")
        if let result {
            #expect(result.isValid)
            #expect(abs((result.volume ?? 0) - 40) < 1e-9)
            #expect(abs((result.surfaceArea ?? 0) - 88) < 1e-9)
        }
    }
}
