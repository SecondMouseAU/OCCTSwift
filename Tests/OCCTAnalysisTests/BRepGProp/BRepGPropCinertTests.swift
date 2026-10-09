import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Cinert Tests")
struct BRepGPropCinertTests {
    @Test("edge curve inertia")
    func edgeCurveInertia() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let edges = box.edges()
        if let edge = edges.first {
            let inertia = edge.curveInertia
            #expect(inertia.length > 0)
        }
    }
}
