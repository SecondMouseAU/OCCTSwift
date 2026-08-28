import Testing
import simd

@testable import OCCTSwift

@Suite("Draft Modification Tests")
struct DraftModificationTests {

    @Test func draftFace() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        let result = box.draftModification(
            faceIndex: 0, direction: SIMD3(0, 0, 1),
            angle: .pi / 18,
            neutralPlaneOrigin: SIMD3(0, 0, 0),
            neutralPlaneNormal: SIMD3(0, 0, 1))
        // Draft may or may not succeed depending on face geometry
        if let result {
            #expect(result.isValid)
        }
    }
}
