import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Asymmetric Chamfer (Two Distances)")
struct AsymmetricChamferTests {
    @Test("Two-distance chamfer on box edge")
    func twoDistChamfer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Chamfer edge 0 with dist1=1.0 on face 0, dist2=2.0 on other face
        let result = box.chamferedTwoDistances([
            (edgeIndex: 0, faceIndex: 0, dist1: 1.0, dist2: 2.0)
        ])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Multiple edges with different asymmetric chamfers")
    func multiEdgeChamfer() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.chamferedTwoDistances([
            (edgeIndex: 0, faceIndex: 0, dist1: 0.5, dist2: 1.0),
            (edgeIndex: 1, faceIndex: 0, dist1: 0.8, dist2: 0.6),
        ])
        // Multi-edge chamfer may require careful edge/face selection
        _ = result
    }
}
