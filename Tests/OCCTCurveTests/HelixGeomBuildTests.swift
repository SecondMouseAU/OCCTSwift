import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.116.0: HelixGeom, gp_Ax3, gp_GTrsf2d, gp_Mat2d, Quaternion Interpolation, XY/XYZ, Math Solvers

@Suite("HelixGeom Build")
struct HelixGeomBuildTests {
    @Test func basicHelixBuild() {
        let result = Helix.build(parameterRange: 0...10, pitch: 5.0, radius: 10.0)
        #expect(result != nil)
        if let r = result { #expect(r.toleranceReached < 0.1) }
    }

    @Test func taperedHelix() {
        let result = Helix.build(
            parameterRange: 0...(6 * .pi), pitch: 5.0, radius: 10.0,
            taperAngle: 5.0 * .pi / 180.0, isClockwise: true)
        #expect(result != nil)
    }

    @Test func helixWithCustomPosition() {
        let result = Helix.build(
            origin: SIMD3(1, 2, 3), parameterRange: 0...10, pitch: 4.0, radius: 8.0)
        #expect(result != nil)
    }

    @Test func coilBuild() {
        let result = Helix.buildCoil(parameterRange: 0...(8 * .pi), pitch: 3.0, radius: 5.0)
        #expect(result != nil)
    }
}
