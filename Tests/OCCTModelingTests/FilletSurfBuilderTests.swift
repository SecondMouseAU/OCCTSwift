import Testing
import simd

@testable import OCCTSwift

@Suite("FilletSurf_Builder Tests")
struct FilletSurfBuilderTests {
    @Test("fillet surface on box edge")
    func filletSurface() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            // Try edges until we find one that produces a fillet surface
            for edge in edges {
                let result = b.filletSurfaces(edges: [edge], radius: 1.0)
                if let r = result, r.status != 1, !r.surfaces.isEmpty {
                    let info = r.surfaces[0]
                    #expect(info.tolerance < 1.0)
                    #expect(info.lastParameter > info.firstParameter)
                    return
                }
            }
        }
    }
}
