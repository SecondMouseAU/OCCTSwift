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
            if let slot = Shape.box(
                origin: SIMD3(cx - 3.0, cy - 1.0, 0.0), width: 6, height: 2, depth: 10)
            {
                if let cut = current.subtracting(slot) {
                    current = cut
                }
            }
        }

        // Drill center bore
        if let bored = current.drilled(
            at: SIMD3(0.0, 0.0, 10.0), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)
        {
            current = bored
        }

        #expect(current.isValid)
        if let finalVol = current.volume {
            #expect(finalVol < originalVolume, "Gear volume should be less than solid cylinder")
            #expect(finalVol > 0)
        }
    }
}
