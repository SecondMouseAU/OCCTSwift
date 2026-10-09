import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema ExtPF Tests")
struct BRepExtremaExtPFTests {
    @Test("Point-face distance")
    func pointFaceDistance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Point above the box - should find distance to one of the faces
        for faceIdx in 0..<6 {
            if let result = box.pointFaceExtrema(point: SIMD3(5, 5, 15), faceIndex: faceIdx) {
                #expect(result.distance >= 0, "Distance should be non-negative")
                #expect(result.solutionCount >= 1)
                break
            }
        }
    }
}
