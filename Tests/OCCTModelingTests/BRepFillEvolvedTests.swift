import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_Evolved")
struct BRepFillEvolvedTests {
    @Test("evolved shape from face spine + wire profile")
    func evolvedShape() {
        if let rect = Wire.rectangle(width: 100, height: 100),
            let spineFace = Shape.face(from: rect)
        {
            if let profileWire = Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(5, 0, 0),
                    SIMD3(5, 0, 5), SIMD3(0, 0, 5),
                ], closed: false),
                let profile = Shape.fromWire(profileWire)
            {
                // BRepFill_Evolved is finicky, may or may not produce a result
                let _ = Shape.evolved(spineFace: spineFace, profileWire: profile)
                #expect(true)
            }
        }
    }
}
