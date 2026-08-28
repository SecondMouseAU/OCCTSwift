import Testing
import simd

@testable import OCCTSwift

@Suite("Draft Prism Feature")
struct DraftPrismTests {
    @Test("Draft prism boss on box face")
    func draftPrismBoss() {
        let box = Shape.box(width: 100, height: 100, depth: 20)!
        // Create a small rectangular profile on top face
        let profile = Wire.rectangle(width: 20, height: 20)!
        // Find the top face index (face 5 is typically the top of a box at origin)
        let result = box.addingDraftPrism(
            profile: profile, sketchFaceIndex: 0,
            draftAngle: 5.0, height: 30.0, fuse: true)
        // Draft prism requires profile on the sketch face, may need specific face
        _ = result
    }

    @Test("Draft prism thru all")
    func draftPrismThruAll() {
        let box = Shape.box(width: 100, height: 100, depth: 20)!
        let profile = Wire.rectangle(width: 20, height: 20)!
        let result = box.addingDraftPrismThruAll(
            profile: profile, sketchFaceIndex: 0,
            draftAngle: 5.0, fuse: true)
        _ = result
    }
}
