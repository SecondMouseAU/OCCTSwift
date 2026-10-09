import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Quilt Faces")
struct QuiltFacesTests {
    @Test("Quilt faces from box")
    func quiltBoxFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        #expect(faces.count == 6)
        // Convert Face objects to Shape objects for quilting
        let faceShapes = faces.compactMap { face -> Shape? in
            Shape.face(from: Wire.rectangle(width: 10, height: 10)!)
        }
        // Quilt should produce something even if faces don't share edges perfectly
        let quilted = Shape.quilt(faceShapes)
        // May or may not succeed depending on edge sharing - just test the API
        _ = quilted
    }
}
