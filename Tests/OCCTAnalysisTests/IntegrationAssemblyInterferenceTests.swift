import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Assembly Interference")
struct IntegrationAssemblyInterferenceTests {

    @Test func shaftHousingClearanceAndInterference() {
        // Step 1-3: Create shaft, housing, bore
        guard let shaft = Shape.cylinder(radius: 10, height: 100),
            let housing = Shape.cylinder(radius: 15, height: 20),
            let bore = Shape.cylinder(radius: 10.05, height: 20)
        else {
            #expect(Bool(false), "Failed to create primitives")
            return
        }

        // Step 4: Housing with bore
        guard let hollowHousing = housing.subtracting(bore) else {
            #expect(Bool(false), "Failed to subtract bore from housing")
            return
        }
        #expect(hollowHousing.isValid)

        // Step 5: Position housing on shaft
        if let positionedHousing = hollowHousing.translated(by: SIMD3(0.0, 0.0, 40.0)) {
            #expect(positionedHousing.isValid)

            // Step 6: Check clearance
            if let distResult = shaft.distance(to: positionedHousing) {
                #expect(distResult.distance >= 0)
            }
        }

        // Step 7: Move housing to interfere (full cylinder, not hollow)
        if let interferingHousing = housing.translated(by: SIMD3(0.0, 0.0, 40.0)) {
            // Step 8-9: Compute interference volume
            if let interference = shaft.intersection(interferingHousing) {
                if let vol = interference.volume {
                    #expect(vol > 0)
                }
            }
        }
    }
}
