import Testing
import simd

@testable import OCCTSwift

@Suite("FilletSurf_Builder Tests")
struct FilletSurfBuilderTests {
    @Test("fillet surface on box edge")
    func filletSurface() throws {
        // #766: this used to loop over the edges and assert only inside
        // `if let r = result, r.status != 1, !r.surfaces.isEmpty`, returning silently if no edge
        // qualified, so a FilletSurf_Builder wrapper that failed on every edge passed. The kernel
        // (Scripts/repro/766-modeling-fillet-surf-builder) builds one surface for every box edge
        // with status IsOk, TolApp3d ~2e-15 and parameter range [0, 10]; the first edge is pinned.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(b.subShapes(ofType: .edge).first)
        let r = try #require(b.filletSurfaces(edges: [edge], radius: 1.0))
        #expect(r.status == 0)  // FilletSurf_IsOk
        #expect(r.surfaces.count == 1)
        let info = try #require(r.surfaces.first)
        #expect(info.tolerance < 1e-6)
        #expect(abs(info.firstParameter) < 1e-9)
        #expect(abs(info.lastParameter - 10.0) < 1e-9)
    }
}
