import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.48.0: Comprehensive Local Operations, Validation, Fixing, Extrema

@Suite("LocOpe Pipe Tests")
struct LocOpePipeTests {
    @Test("Pipe sweep along wire spine")
    func pipeSweep() throws {
        // LocOpe_Pipe needs a face profile, create a planar face from a wire
        let profileWire = Wire.rectangle(width: 2, height: 2)!
        let profileFace = Shape.face(from: profileWire)!
        let spine = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let result = profileFace.localPipe(along: spine)
        #expect(result != nil, "Pipe sweep should produce a shape")
    }
}
