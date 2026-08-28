import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill DiscreteTrihedron")
struct GeomFillDiscreteTrihedronTests {
    @Test("Discrete trihedron on edge")
    func discreteTrihedronEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        for edge in edges {
            if let frame = edge.discreteTrihedron(at: 0) {
                #expect(simd_length(frame.tangent) > 0.1)
                return
            }
        }
    }
}
