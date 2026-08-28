import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill CorrectedFrenet")
struct GeomFillCorrectedFrenetTests {
    @Test("Corrected Frenet on edge")
    func correctedFrenetEdge() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        for edge in edges {
            if let frame = edge.correctedFrenet(at: 0) {
                #expect(simd_length(frame.tangent) > 0.1)
                return
            }
        }
    }
}
