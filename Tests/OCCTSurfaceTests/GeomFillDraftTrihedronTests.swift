import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill DraftTrihedron")
struct GeomFillDraftTrihedronTests {
    @Test("Draft trihedron on circle edge")
    func draftTrihedronCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        for edge in edges {
            if let frame = edge.draftTrihedron(at: 0, biNormal: SIMD3(0, 0, 1), angle: .pi / 6) {
                #expect(simd_length(frame.tangent) > 0.1)
                #expect(simd_length(frame.normal) > 0.1)
                #expect(simd_length(frame.binormal) > 0.1)
                return
            }
        }
    }
}
