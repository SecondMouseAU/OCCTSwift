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
        }
    }

    @Test("Pipe with section curve")
    func pipeWithSection() {
        let path = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(0, 0, 10))!
        let section = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 3)!
        let pipe = Surface.pipe(path: path, section: section)
        #expect(pipe != nil)
    }
}
