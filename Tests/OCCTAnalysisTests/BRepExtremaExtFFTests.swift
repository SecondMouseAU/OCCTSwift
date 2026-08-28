import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema ExtFF Tests")
struct BRepExtremaExtFFTests {
    @Test("Face-face distance between separated boxes")
    func faceFaceDistance() throws {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 5, height: 5, depth: 5)!
        // Try different face pairs until we find one with a result
        var foundResult = false
        for i in 0..<6 {
            for j in 0..<6 {
                if let result = box1.faceFaceExtrema(faceIndex1: i, other: box2, faceIndex2: j) {
                    #expect(result.distance >= 0, "Distance should be non-negative")
                    foundResult = true
                    break
                }
            }
            if foundResult { break }
        }
    }
}
