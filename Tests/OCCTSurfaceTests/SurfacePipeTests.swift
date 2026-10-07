import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Pipe")
struct SurfacePipeTests {
    @Test("Pipe with circular cross-section")
    func pipeCircular() {
        let path = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 10))!
        let pipe = Surface.pipe(path: path, radius: 2)
        #expect(pipe != nil)
        if let pipe = pipe {
            let dom = pipe.domain
            #expect(dom.uMin < dom.uMax)
            #expect(dom.vMin < dom.vMax)
            // #766: ordered bounds passed any pipe. GeomFill_Pipe gives [0, 2 pi] x [0, 10] and,
            // at 30% / 60% of it, a point at radius 2 (Scripts/repro/766-surface-operations-pipe/).
            #expect(dom.uMax == 2 * .pi && dom.vMax == 10)
            let p = pipe.point(atU: 0.3 * dom.uMax, v: 6)
            #expect(simd_length(p - SIMD3(-1.9021130325903073, -0.61803398874989446, 6)) < 1e-9)
        }
    }

    @Test("Pipe with section curve")
    func pipeWithSection() {
        let path = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 10))!
        let section = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 3)!
        let pipe = Surface.pipe(path: path, section: section)
        #expect(pipe != nil)
        // #766: was non-nil only; the section's radius 3 must carry through.
        if let pipe {
            let p = pipe.point(atU: 0.3 * pipe.domain.uMax, v: 6)
            #expect(simd_length(p - SIMD3(-0.92705098312484202, 2.8531695488854609, 6)) < 1e-9)
        }
    }
}
