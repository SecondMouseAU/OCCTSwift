import Testing
import simd

@testable import OCCTSwift

@Suite("Revolution Feature")
struct RevolutionFeatureTests {

    // #766: both ended in `_ = result`, so they asserted nothing. Their profile also lay at z = 0,
    // inside the box and off the sketch face, and the kernel returned the box unchanged (volume
    // 8,000,000 both times), so even a volume check would have passed a feature that did nothing.
    // The profile now lies on the top face (z = 100, face index 5) and revolves about a Y axis at
    // x = 50, z = 100: a 90-degree boss adds 100 * pi/4 * (75^2 - 25^2) = 392,699. Values from
    // BRepFeat_MakeRevol (Scripts/repro/766-projection-trim-revolution-section/).
    private let topProfile = Wire.path(
        [SIMD3(-25, -50, 100), SIMD3(25, -50, 100), SIMD3(25, 50, 100), SIMD3(-25, 50, 100)], closed: true)
    @Test("Revolved boss on box")
    func revolvedBoss() {
        let box = Shape.box(width: 200, height: 200, depth: 200)!
        let profile = topProfile!
        let result = box.addingRevolvedFeature(
            profile: profile,
            sketchFaceIndex: 5,
            axisOrigin: SIMD3(50, 0, 100),
            axisDirection: SIMD3(0, 1, 0),
            angle: 90
        )
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(abs((result.volume ?? 0) - 8392699.0816987269) < 1e-3)
        }
    }

    @Test("Revolved feature thru all (360)")
    func revolvedThruAll() {
        let box = Shape.box(width: 200, height: 200, depth: 200)!
        let profile = topProfile!
        let result = box.addingRevolvedFeatureThruAll(
            profile: profile,
            sketchFaceIndex: 5,
            axisOrigin: SIMD3(50, 0, 100),
            axisDirection: SIMD3(0, 1, 0)
        )
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(abs((result.volume ?? 0) - 8882194.4784009419) < 1e-3)
        }
    }
}
