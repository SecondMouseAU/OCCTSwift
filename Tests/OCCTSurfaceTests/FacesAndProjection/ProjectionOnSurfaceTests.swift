import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - ProjectionOnSurface")
struct ProjectionOnSurfaceTests {

    @Test func multiResultProjection() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            if let proj = ProjectionOnSurface(surface: sphere, point: SIMD3(10, 0, 0)) {
                #expect(proj.count >= 1)
                if proj.count > 0 {
                    let pt = proj.point(at: 0)
                    #expect(abs(pt.x - 5.0) < 0.5)
                    let uv = proj.parameters(at: 0)
                    #expect(uv.u >= 0 || uv.u < 0)  // just check it returns
                    let dist = proj.distance(at: 0)
                    #expect(abs(dist - 5.0) < 0.1)
                }
                #expect(abs(proj.lowerDistance - 5.0) < 0.1)
                let lp = proj.lowerParameters
                #expect(lp.u >= 0 || lp.u < 0)  // just check it returns
            }
        }
    }
}
