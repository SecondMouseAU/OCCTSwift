import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Assembly Interference")
struct IntegrationAssemblyInterferenceTests {

    /// Clearance and interference of a shaft in a housing.
    ///
    /// A shaft (r = 10) through a housing (r = 15, h = 20) with a bore of r = 10.05, raised 40
    /// along the shaft. The version of this test before #1890 asserted `distance >= 0` and
    /// `vol > 0`, both inside `if let`, so a bridge returning any non-negative distance or any
    /// volume passed, and one returning nil passed too. The radial clearance is 0.05 and the
    /// interfering (unbored) housing overlaps the shaft in a r = 10, h = 20 cylinder, both
    /// measured in Scripts/repro/766-integration-assembly-interference-tests/transcript.txt.
    @Test func shaftHousingClearanceAndInterference() {
        // Step 1-3: Create shaft, housing, bore
        guard let shaft = Shape.cylinder(radius: 10, height: 100),
            let housing = Shape.cylinder(radius: 15, height: 20),
            let bore = Shape.cylinder(radius: 10.05, height: 20)
        else {
            Issue.record("Failed to create primitives")
            return
        }

        // Step 4: Housing with bore
        guard let hollowHousing = housing.subtracting(bore) else {
            Issue.record("Failed to subtract bore from housing")
            return
        }
        #expect(hollowHousing.isValid)
        let hollowVolume = Double.pi * (15 * 15 - 10.05 * 10.05) * 20
        if let v = hollowHousing.volume {
            #expect(abs(v - hollowVolume) < 1e-6, "bored housing volume \(hollowVolume), got \(v)")
        } else {
            Issue.record("the bored housing has a volume")
        }

        // Step 5: Position housing on shaft
        guard let positionedHousing = hollowHousing.translated(by: SIMD3(0.0, 0.0, 40.0)) else {
            Issue.record("translated(by:) returned nil")
            return
        }
        #expect(positionedHousing.isValid)

        // Step 6: Check clearance, 10.05 - 10 radially
        guard let distResult = shaft.distance(to: positionedHousing) else {
            Issue.record("distance(to:) returned nil")
            return
        }
        #expect(
            abs(distResult.distance - 0.05) < 1e-9,
            "radial clearance 0.05, got \(distResult.distance)")

        // Step 7: Move housing to interfere (full cylinder, not hollow)
        guard let interferingHousing = housing.translated(by: SIMD3(0.0, 0.0, 40.0)) else {
            Issue.record("translated(by:) returned nil")
            return
        }
        // Step 8-9: Compute interference volume, the r = 10, h = 20 slice of the shaft
        guard let interference = shaft.intersection(interferingHousing) else {
            Issue.record("intersection returned nil")
            return
        }
        guard let vol = interference.volume else {
            Issue.record("the interference has a volume")
            return
        }
        let expected = Double.pi * 10 * 10 * 20
        #expect(abs(vol - expected) < 1e-6, "interference volume \(expected), got \(vol)")
    }
}
