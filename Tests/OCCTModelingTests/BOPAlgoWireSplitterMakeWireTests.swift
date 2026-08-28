import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_WireSplitter MakeWire Tests")
struct BOPAlgoWireSplitterMakeWireTests {
    @Test("make wire from edges")
    func makeWireFromEdges() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)
        let e1 = Shape.edgeFromPoints(p1, p2)
        let e2 = Shape.edgeFromPoints(p2, p3)
        let e3 = Shape.edgeFromPoints(p3, p4)
        let e4 = Shape.edgeFromPoints(p4, p1)
        if let e1, let e2, let e3, let e4 {
            let wire = Shape.makeWire(from: [e1, e2, e3, e4])
            if let w = wire {
                let edges = w.subShapes(ofType: .edge)
                #expect(edges.count == 4)
            }
        }
    }
}
