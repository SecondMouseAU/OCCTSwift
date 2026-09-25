import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill DraftTrihedron")
struct GeomFillDraftTrihedronTests {
    @Test("Draft trihedron on circle edge")
    func draftTrihedronCircle() throws {
        // #766: this looped over edges until one answered and checked only that each vector
        // was longer than 0.1, so an ignored draft angle passed. On edge 0 (the top circle) at 0,
        // GeomFill_DraftTrihedron(+Z, pi/6) gives T (0, -1, 0), N (cos 30, 0, -sin 30),
        // B (sin 30, 0, cos 30), see Scripts/repro/766-geomfill-a/. (Its T is opposite GeomFill_CorrectedFrenet's
        // on the same edge; that is the kernel's convention.)
        let cyl = try #require(Shape.cylinder(radius: 10, height: 5))
        let edge = try #require(cyl.subShapes(ofType: .edge).first)
        let frame = try #require(
            edge.draftTrihedron(at: 0, biNormal: SIMD3(0, 0, 1), angle: .pi / 6))
        #expect(simd_length(frame.tangent - SIMD3(0, -1, 0)) < 1e-9)
        #expect(simd_length(frame.normal - SIMD3(0.866025403784, 0, -0.5)) < 1e-9)
        #expect(simd_length(frame.binormal - SIMD3(0.5, 0, 0.866025403784)) < 1e-9)
    }
}
