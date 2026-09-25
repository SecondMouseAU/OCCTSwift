import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - ProjectionOnSurface")
struct ProjectionOnSurfaceTests {

    @Test func multiResultProjection() {
        // #766: two expectations were `u >= 0 || u < 0`, true for any value, and all sat behind
        // `if let`s. GeomAPI_ProjectPointOnSurf finds both extrema, the near point (5, 0, 0) at
        // (0, 0), distance 5, and the far one (-5, 0, 0) at (pi, 0), distance 15 (Scripts/repro/766-projection-trim-revolution-section/).
        let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)
        let proj = sphere.flatMap { ProjectionOnSurface(surface: $0, point: SIMD3(10, 0, 0)) }
        #expect(proj != nil)
        if let proj {
            #expect(proj.count == 2)
            if proj.count == 2 {
                #expect(simd_length(proj.point(at: 0) - SIMD3(5, 0, 0)) < 1e-9)
                let uv = proj.parameters(at: 0)
                #expect(abs(uv.u) < 1e-9 && abs(uv.v) < 1e-9)
                #expect(abs(proj.distance(at: 0) - 5.0) < 1e-9)
                #expect(abs(proj.distance(at: 1) - 15.0) < 1e-9)
                #expect(abs(proj.parameters(at: 1).u - .pi) < 1e-9)
            }
            #expect(abs(proj.lowerDistance - 5.0) < 1e-9)
            let lp = proj.lowerParameters
            #expect(abs(lp.u) < 1e-9 && abs(lp.v) < 1e-9)
        }
    }
}
