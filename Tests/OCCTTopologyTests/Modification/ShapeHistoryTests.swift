import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_History")
struct ShapeHistoryTests {
    @Test("Track modifications and removals")
    func history() throws {
        let history = try #require(Shape.History())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count >= 6)
        let face1 = faces[0]
        let face2 = faces[1]

        let smallBox = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let newFace = smallBox.subShapes(ofType: .face)[0]

        history.addModified(initial: face1, modified: newFace)
        history.remove(face2)

        #expect(history.hasModified)
        #expect(history.hasRemoved)
        #expect(!history.hasGenerated)
        #expect(history.isRemoved(face2))
        #expect(!history.isRemoved(face1))
        #expect(history.modifiedCount(of: face1) == 1)
    }
}
