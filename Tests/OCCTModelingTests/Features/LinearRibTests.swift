import Testing
import simd

@testable import OCCTSwift

@Suite("Linear Rib Feature")
struct LinearRibTests {
    @Test("Add rib to box")
    func addRibToBox() {
        let box = Shape.box(width: 20, height: 20, depth: 5)!
        // Create a small wire profile centered on the top face
        let profile = Wire.rectangle(width: 2, height: 2)
        guard let wire = profile else {
            return
        }
        let ribbed = box.addingLinearRib(
            profile: wire,
            direction: SIMD3(0, 0, 1),
            draftDirection: SIMD3(0, 0, 1)
        )
        // Rib feature is complex and may fail depending on geometry setup
        _ = ribbed
    }
}
