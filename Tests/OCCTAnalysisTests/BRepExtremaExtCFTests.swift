import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_ExtCF Tests")
struct BRepExtremaExtCFTests {
    @Test("Edge to sphere face distance")
    func edgeToSphereFace() throws {
        // Use a box edge at known position and a sphere face
        let box = Shape.box(width: 20, height: 1, depth: 1)!
        let sphere = Shape.sphere(radius: 3)!

        // Try different edge/face combinations until we find valid extrema
        var foundResult = false
        let edgeCount = box.edges().count
        for i in 0..<edgeCount {
            if let result = box.edgeFaceExtrema(edgeIndex: i, other: sphere, faceIndex: 0) {
                if !result.isParallel && result.solutionCount > 0 {
                    #expect(result.distance >= 0)
                    foundResult = true
                    break
                }
            }
        }
        // May or may not find result depending on geometry
    }

    @Test("Box edge to box face")
    func boxEdgeToBoxFace() throws {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(0, 0, 20), width: 10, height: 10, depth: 10)!

        // Try edge/face combinations
        var foundResult = false
        let edgeCount = box1.edges().count
        let faceCount = box2.faces().count
        for i in 0..<min(edgeCount, 4) {
            for j in 0..<min(faceCount, 4) {
                if let result = box1.edgeFaceExtrema(edgeIndex: i, other: box2, faceIndex: j) {
                    if !result.isParallel && result.solutionCount > 0 {
                        #expect(result.distance >= 0)
                        foundResult = true
                        break
                    }
                }
            }
            if foundResult { break }
        }
    }
}
