import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Boolean Chain Stress")
struct IntegrationBooleanChainStressTests {

    @Test func twentySubtractions() {
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else {
            #expect(false, "Failed to create box")
            return
        }
        let origVolume = shape.volume ?? 0
        #expect(origVolume > 0)

        var prevVolume = origVolume
        for i in 0..<20 {
            let angle = Double(i) * (2.0 * .pi / 20.0)
            let x = 30.0 * cos(angle)
            let y = 30.0 * sin(angle)
            if let sphere = Shape.sphere(radius: 5),
                let positioned = sphere.translated(by: SIMD3(x, y, 0.0)),
                let result = shape.subtracting(positioned)
            {
                shape = result
            }

            // Every 5 subtractions, check validity and volume
            if (i + 1) % 5 == 0 {
                #expect(shape.isValid)
                if let vol = shape.volume {
                    #expect(vol < prevVolume)
                    prevVolume = vol
                }
            }
        }

        // Final checks
        #expect(shape.isValid)
        if let finalVol = shape.volume {
            #expect(finalVol < origVolume)
        }
    }
}
