import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values pinned to GeomAPI_ProjectPointOnCurve on the pinned kernel
// (Scripts/repro/766-curve-final-sampling/transcript.txt): projecting (10,0,0) onto the r=5
// circle gives two extrema, the near one (5,0,0) at u=0 and the far one (-5,0,0) at u=pi.
@Suite("v0.113.0 - ProjectionOnCurve")
struct ProjectionOnCurveTests {

    @Test func multiResultProjection() {
        guard
            let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let proj = ProjectionOnCurve(curve: circ, point: SIMD3(10, 0, 0))
        else {
            Issue.record("circle or projection was nil")
            return
        }
        #expect(proj.count == 2)
        guard proj.count == 2 else { return }
        #expect(simd_distance(proj.point(at: 0), SIMD3(5, 0, 0)) < 1e-9)
        #expect(abs(proj.distance(at: 0) - 5.0) < 1e-9)
        #expect(simd_distance(proj.point(at: 1), SIMD3(-5, 0, 0)) < 1e-9)
        #expect(abs(proj.distance(at: 1) - 15.0) < 1e-9)
        #expect(abs(proj.lowerDistance - 5.0) < 1e-9)
    }

    @Test func parameterAccess() {
        guard
            let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let proj = ProjectionOnCurve(curve: circ, point: SIMD3(10, 0, 0))
        else {
            Issue.record("circle or projection was nil")
            return
        }
        #expect(proj.count == 2)
        guard proj.count == 2 else { return }
        // (5,0,0) is the circle's origin point, u = 0; the far extremum (-5,0,0) is u = pi.
        #expect(abs(proj.parameter(at: 0)) < 1e-9)
        #expect(abs(proj.parameter(at: 1) - .pi) < 1e-9)
        #expect(abs(proj.lowerParameter) < 1e-9)
    }
}
