import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.77.0 Tests

@Suite("GeomLib Tool Tests")
struct GeomLibToolTests {
    @Test("parameter on 3D line")
    func parameterOn3DLine() {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let param = try #require(line.parameterOf(point: SIMD3(5, 0, 0)))
        #expect(abs(param - 5.0) < 1e-6)
    }

    @Test("parameters on surface")
    func parametersOnSurface() {
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let uv = try #require(plane.parametersOf(point: SIMD3(3, 4, 0)))
        #expect(abs(uv.u - 3.0) < 1e-6)
        #expect(abs(uv.v - 4.0) < 1e-6)
    }

    @Test("parameter on 2D line")
    func parameterOn2DLine() {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let param = try #require(line.parameterOf(point: SIMD2(7, 0)))
        #expect(abs(param - 7.0) < 1e-6)
    }
}

