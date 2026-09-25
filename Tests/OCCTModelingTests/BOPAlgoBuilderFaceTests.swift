import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo_BuilderFace Tests")
struct BOPAlgoBuilderFaceTests {
    @Test("Build face from boundary edges")
    func buildFaceFromEdges() throws {
        // Create a face and rebuild it from its own edges
        // #766: every step used to sit in a nested `if let`, so a fixture that failed to build
        // skipped all the assertions, and the count was only `>= 1`. The fixtures are now
        // `try #require`, and the kernel's answer is pinned (Scripts/repro/766-modeling-bopalgo-
        // builder-face): BOPAlgo_BuilderFace on the 10 x 10 plane face's own 4 edges returns
        // exactly 1 face of area 100.
        let s = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let f = try #require(Shape.face(from: s, uRange: -5...5, vRange: -5...5))
        let edges = f.subShapes(ofType: .edge)
        try #require(edges.count == 4)
        let r = try #require(f.buildFaces(from: edges))
        #expect(r.count >= 1)
        #expect(r.count == 1)
        let first = try #require(r.first)
        let area = try #require(first.surfaceArea)
        #expect(abs(area - 100) < 1e-6)
    }
}
