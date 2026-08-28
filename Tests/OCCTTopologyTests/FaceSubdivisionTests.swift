import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.43.0: Face Subdivision by Area

@Suite("Face Subdivision by Area")
struct FaceSubdivisionTests {
    @Test("Divide box faces by area")
    func divideByArea() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let origFaces = box.subShapeCount(ofType: .face)
        #expect(origFaces == 6)

        // Each face is 100 sq units; maxArea=25 should split them
        let result = box.dividedByArea(maxArea: 25)
        #expect(result != nil)
        if let result {
            let newFaces = result.subShapeCount(ofType: .face)
            #expect(newFaces > origFaces)
        }
    }

    @Test("Large max area does not split")
    func largeAreaNoSplit() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByArea(maxArea: 10000)
        #expect(result != nil)
        if let result {
            #expect(result.subShapeCount(ofType: .face) == 6)
        }
    }

    @Test("Divide by parts")
    func divideByParts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByParts(4)
        #expect(result != nil)
        if let result {
            #expect(result.subShapeCount(ofType: .face) > 6)
        }
    }
}
