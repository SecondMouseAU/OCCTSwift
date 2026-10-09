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
            // #766: this was `if let ..., let result = shape.subtracting(positioned) { shape = result }`,
            // which dropped a subtraction that returned nil and carried on with the shape unchanged.
            // The volume checkpoints below only need one cut in five to land, so a chain that lost
            // most of its cuts still passed. The kernel completes all twenty
            // (Scripts/repro/766-modeling-integration-boolean-chain-stress), so a nil is a failure.
            guard let sphere = Shape.sphere(radius: 5),
                let positioned = sphere.translated(by: SIMD3(x, y, 0.0)),
                let result = shape.subtracting(positioned)
            else {
                Issue.record("subtraction \(i + 1) of 20 produced no shape")
                return
            }
            shape = result

            // Every 5 subtractions, check validity and volume
            if (i + 1) % 5 == 0 {
                #expect(shape.isValid)
                guard let vol = shape.volume else {
                    Issue.record("no volume after \(i + 1) subtractions")
                    return
                }
                #expect(vol < prevVolume)
                prevVolume = vol
            }
        }

        // Final checks
        #expect(shape.isValid)
        guard let finalVol = shape.volume else {
            Issue.record("no volume after 20 subtractions")
            return
        }
        #expect(finalVol < origVolume)
        // The kernel's own answer for this chain: 989586.0182 (the twenty r=5 spheres are not all
        // disjoint, so a little under the 10471.98 they would remove if they were).
        #expect(abs(finalVol - 989586.0182) < 1e-3)
    }
}
