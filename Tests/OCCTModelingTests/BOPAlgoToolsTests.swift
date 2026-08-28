import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_Tools Tests")
struct BOPAlgoToolsTests {
    @Test("EdgesToWires from rectangle edges")
    func edgesToWires() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        let e3 = Shape.edgeFromPoints(SIMD3(10, 10, 0), SIMD3(0, 10, 0))
        let e4 = Shape.edgeFromPoints(SIMD3(0, 10, 0), SIMD3(0, 0, 0))
        if let edge1 = e1, let edge2 = e2, let edge3 = e3, let edge4 = e4 {
            let compound = Shape.compound([edge1, edge2, edge3, edge4])
            if let c = compound {
                let result = c.edgesToWires()
                #expect(result != nil)
                if let r = result {
                    let wires = r.subShapes(ofType: .wire)
                    #expect(wires.count >= 1)
                }
            }
        }
    }

    @Test("WiresToFaces from edge compound via EdgesToWires")
    func wiresToFaces() {
        // First convert edges to wires, then wires to faces
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        let e3 = Shape.edgeFromPoints(SIMD3(10, 10, 0), SIMD3(0, 10, 0))
        let e4 = Shape.edgeFromPoints(SIMD3(0, 10, 0), SIMD3(0, 0, 0))
        if let edge1 = e1, let edge2 = e2, let edge3 = e3, let edge4 = e4 {
            let compound = Shape.compound([edge1, edge2, edge3, edge4])
            if let c = compound {
                let wires = c.edgesToWires()
                if let w = wires {
                    let result = w.wiresToFaces()
                    #expect(result != nil)
                    if let r = result {
                        let faces = r.subShapes(ofType: .face)
                        #expect(faces.count >= 1)
                    }
                }
            }
        }
    }
}
