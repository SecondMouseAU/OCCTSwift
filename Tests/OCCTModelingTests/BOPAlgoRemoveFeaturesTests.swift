import Testing
import simd

@testable import OCCTSwift

// ============================================================
// v0.65.0: Shape Processing Completions + Boolean Completions
// ============================================================

// MARK: - BOPAlgo_RemoveFeatures

// These used to call removeFeatures(faces:), which drove BOPAlgo_RemoveFeatures directly. #536
// found it identical to defeature(faces:) (the same algorithm through BRepAlgoAPI_Defeaturing one
// layer up), deprecated it as a forwarder, and removeFeatures(faces:) was removed at v2.0.0 (#784).
@Suite("BOPAlgo RemoveFeatures")
struct BOPAlgoRemoveFeaturesTests {
    @Test("Remove fillet from box")
    func removeFilletFromBox() {
        guard let box = Shape.box(width: 20, height: 20, depth: 20) else { return }
        // Add fillet to all edges
        if let filleted = box.filleted(radius: 2.0) {
            let filletedFaces = filleted.subShapes(ofType: .face)
            // Fillet adds faces, try removing the last face
            guard filletedFaces.count > 6 else { return }
            let lastFace = filletedFaces[filletedFaces.count - 1]
            if let result = filleted.defeature(faces: [lastFace]) {
                #expect(result.isValid)
                let resultFaces = result.subShapes(ofType: .face)
                #expect(resultFaces.count <= filletedFaces.count)
            }
        }
    }

    @Test("Remove features returns nil for empty faces")
    func removeFeaturesEmptyFaces() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.defeature(faces: [])
        #expect(result == nil)
    }

    @Test("Remove face from box")
    func removeFaceFromBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // Removing a face from a box may or may not succeed
        // depending on topology, just verify it doesn't crash
        let _ = box.defeature(faces: [faces[0]])
    }
}
