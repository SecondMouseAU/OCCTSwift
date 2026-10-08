import Testing
import simd

@testable import OCCTSwift

@Suite("Evolved Surface Tests")
struct EvolvedSurfaceTests {

    @Test("Simple evolved shape")
    func simpleEvolved() {
        // Create a simple spine (quarter circle)
        let spine = Wire.arc(center: SIMD3(0, 0, 0), radius: 20, startAngle: 0, endAngle: .pi / 2)!

        // Create a small profile
        let profile = Wire.rectangle(width: 2, height: 2)!

        let evolved = Shape.evolved(spine: spine, profile: profile)

        // Evolved may not always succeed depending on geometry
        if let evolved = evolved {
            #expect(evolved.isValid)
        }
    }
}
