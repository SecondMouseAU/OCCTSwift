import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.77.0 Tests

// Pinned to the kernel values in Scripts/repro/766-math-geomlib-interp-planar-tool/transcript.txt
// (parameterOn3DLine: ok=1 param=5, parametersOnSurface: ok=1 u=3 v=4, parameterOn2DLine: ok=1
// param=7). Every setup and result is required, not nested in `if let`: a nil curve, a nil
// surface or a nil parameter must fail the test rather than skip its assertions.
@Suite("GeomLib Tool Tests")
struct GeomLibToolTests {
    @Test("parameter on 3D line")
    func parameterOn3DLine() throws {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let param = try #require(line.parameterOf(point: SIMD3(5, 0, 0)))
        #expect(abs(param - 5.0) < 1e-9)
    }

    @Test("parameters on surface")
    func parametersOnSurface() throws {
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let uv = try #require(plane.parametersOf(point: SIMD3(3, 4, 0)))
        #expect(abs(uv.u - 3.0) < 1e-9)
        #expect(abs(uv.v - 4.0) < 1e-9)
    }

    @Test("parameter on 2D line")
    func parameterOn2DLine() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let param = try #require(line.parameterOf(point: SIMD2(7, 0)))
        #expect(abs(param - 7.0) < 1e-9)
    }
}
