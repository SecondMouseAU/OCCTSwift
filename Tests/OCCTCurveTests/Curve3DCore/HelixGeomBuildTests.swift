import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.116.0: HelixGeom, gp_Ax3, gp_GTrsf2d, gp_Mat2d, Quaternion Interpolation, XY/XYZ, Math Solvers

// Pinned to HelixGeom_BuilderHelix / HelixGeom_BuilderHelixCoil on the same parameters
// (Scripts/repro/766-curve-helix/transcript.txt). The earlier versions checked only `!= nil`
// (and basicHelixBuild a tolerance bound inside `if let`), so a helix with the wrong pitch or
// position passed (#766).
@Suite("HelixGeom Build")
struct HelixGeomBuildTests {
    @Test func basicHelixBuild() {
        guard let r = Helix.build(parameterRange: 0...10, pitch: 5.0, radius: 10.0) else {
            Issue.record("helix not built")
            return
        }
        #expect(r.toleranceReached < 0.1)
        // The kernel places the end one pitch up the axis, at (10, 0, 5).
        let end = r.curve.endPoint
        #expect(simd_distance(r.curve.startPoint, SIMD3(10, 0, 0)) < 1e-9)
        #expect(simd_distance(end, SIMD3(10, 0, 5)) < 1e-9)
    }

    @Test func taperedHelix() {
        guard
            let r = Helix.build(
                parameterRange: 0...(6 * .pi), pitch: 5.0, radius: 10.0,
                taperAngle: 5.0 * .pi / 180.0, isClockwise: true)
        else {
            Issue.record("tapered helix not built")
            return
        }
        // The kernel ends the tapered helix at (10.437, 0, 5).
        #expect(simd_distance(r.curve.endPoint, SIMD3(10.437443317629619, 0, 5)) < 1e-6)
    }

    @Test func helixWithCustomPosition() {
        guard
            let r = Helix.build(
                origin: SIMD3(1, 2, 3), parameterRange: 0...10, pitch: 4.0, radius: 8.0)
        else {
            Issue.record("positioned helix not built")
            return
        }
        #expect(simd_distance(r.curve.startPoint, SIMD3(9, 2, 3)) < 1e-9)
        #expect(simd_distance(r.curve.endPoint, SIMD3(9, 2, 7)) < 1e-9)
    }

    @Test func coilBuild() {
        guard let r = Helix.buildCoil(parameterRange: 0...(8 * .pi), pitch: 3.0, radius: 5.0) else {
            Issue.record("coil not built")
            return
        }
        // Four turns of pitch 3 climb to z = 12.
        #expect(simd_distance(r.curve.endPoint, SIMD3(5, 0, 12)) < 1e-9)
    }
}
