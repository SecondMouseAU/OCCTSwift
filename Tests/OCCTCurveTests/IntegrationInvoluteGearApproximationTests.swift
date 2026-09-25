import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Integration Tests: Design Workflows

@Suite("Integration: Involute Gear Approximation")
struct IntegrationInvoluteGearApproximationTests {

    @Test func gearWithSlotsAndBore() {
        // Create cylindrical hub
        guard let hub = Shape.cylinder(radius: 20, height: 10) else {
            #expect(Bool(false), "Failed to create hub cylinder")
            return
        }
        #expect(hub.isValid)
        let originalVolume = hub.volume ?? 0
        #expect(originalVolume > 0)

        // Create 6 radial slots as boxes and subtract them
        var current = hub
        for i in 0..<6 {
            let angle = Double(i) * (.pi / 3.0)  // 60 degree spacing
            let cx = 15.0 * cos(angle)
            let cy = 15.0 * sin(angle)
            // Create a small box for each slot, then rotate it
            // #766: a failed cut or drill used to be skipped silently, and the only check was
            // "smaller than the hub", which the bore alone satisfies.
            guard
                let slot = Shape.box(
                    origin: SIMD3(cx - 3.0, cy - 1.0, 0.0), width: 6, height: 2, depth: 10),
                let cut = current.subtracting(slot)
            else {
                Issue.record("slot \(i) was not cut")
                return
            }
            current = cut
        }

        // Drill center bore
        guard
            let bored = current.drilled(
                at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)
        else {
            Issue.record("the bore was not drilled")
            return
        }
        current = bored

        #expect(current.isValid)
        // The slots miss each other, the rim and the bore, so the result is exact:
        // 4000pi hub - 6 * 120 slots - 250pi bore. BRepAlgoAPI_Cut of the same solids gives
        // 11060.972450961723 (Scripts/repro/766-curve-integration-extrema-law).
        if let finalVol = current.volume {
            #expect(abs(finalVol - (3750 * .pi - 720)) < 1e-6, "gear volume \(finalVol)")
        } else {
            Issue.record("gear volume was nil")
        }
    }
}
