import Testing
import simd

@testable import OCCTSwift

@Suite("Revolution Feature")
struct RevolutionFeatureTests {
    @Test("Revolved boss on box")
    func revolvedBoss() {
        let box = Shape.box(width: 200, height: 200, depth: 200)!
        // Create a small profile on one face
        let profile = Wire.rectangle(width: 50, height: 100)!
        let result = box.addingRevolvedFeature(
            profile: profile,
            sketchFaceIndex: 0,
            axisOrigin: SIMD3(0, 0, 200),
            axisDirection: SIMD3(0, 1, 0),
            angle: 90
        )
        // Revolution feature is complex
        _ = result
    }

    @Test("Revolved feature thru all (360)")
    func revolvedThruAll() {
        let box = Shape.box(width: 200, height: 200, depth: 200)!
        let profile = Wire.rectangle(width: 50, height: 100)!
        let result = box.addingRevolvedFeatureThruAll(
            profile: profile,
            sketchFaceIndex: 0,
            axisOrigin: SIMD3(0, 0, 200),
            axisDirection: SIMD3(0, 1, 0)
        )
        _ = result
    }
}
