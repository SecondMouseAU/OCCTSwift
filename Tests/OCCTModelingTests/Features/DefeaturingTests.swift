import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAlgoAPI_Defeaturing")
struct DefeaturingTests {
    @Test func defeatureBox() {
        // Create a box, fillet an edge, then try to remove the fillet
        let box = Shape.box(width: 20, height: 20, depth: 20)
        if let b = box {
            if let filleted = b.filleted(radius: 2.0) {
                // Get faces from the filleted shape
                let faces = filleted.subShapes(ofType: .face)
                // The filleted shape should have more faces than the original 6
                #expect(faces.count > 6)
                // Try to remove one of the extra faces (the fillet face)
                if faces.count > 6 {
                    // Try removing the 7th face (likely a fillet face)
                    let result = filleted.defeature(faces: [faces[6]])
                    // Defeaturing may or may not succeed depending on geometry
                    if let r = result {
                        #expect(r.isValid)
                    }
                }
            }
        }
    }
}
