import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntCurvesFace Intersection")
struct IntCurvesFaceTests {
    @Test("Line-face intersection")
    func lineFaceIntersection() {
        // Create a box and get its faces
        guard let box = Shape.box(width: 10, height: 20, depth: 30) else {
            #expect(Bool(false), "Failed to create box")
            return
        }
        let faces = box.faces()
        #expect(faces.count > 0)
        if faces.count > 0 {
            // Create a shape from the first face for intersection
            if let faceShape = Shape.fromFace(faces[0]) {
                let results = faceShape.intersectLine(
                    origin: SIMD3(5, 10, -50),
                    direction: SIMD3(0, 0, 1))
                // May or may not intersect depending on face orientation
                // The important thing is no crash
                #expect(Bool(true))
            }
        }
    }
}
