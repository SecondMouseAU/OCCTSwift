import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Values are the pinned kernel's `Geom_BezierSurface`, read by `Scripts/repro/766-bezier-surface/`
/// on the same 3 x 3 net. The net is symmetric in its degrees and at its corner pole, so every test
/// that could be satisfied by a transposed or unchanged surface also reads an off-diagonal pole.
@Suite("BezierSurface_Properties")
struct BezierSurfaceTests {
    func makeBezierSurface() -> Surface? {
        Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 5, 1), SIMD3(0, 10, 0)],
            [SIMD3(5, 0, 1), SIMD3(5, 5, 2), SIMD3(5, 10, 1)],
            [SIMD3(10, 0, 0), SIMD3(10, 5, 1), SIMD3(10, 10, 0)],
        ])
    }

    @Test func nbPoles() throws {
        let bp = try #require(makeBezierSurface()).bezierProperties
        #expect(bp.nbUPoles == 3)
        #expect(bp.nbVPoles == 3)
    }

    @Test func degree() throws {
        let bp = try #require(makeBezierSurface()).bezierProperties
        #expect(bp.uDegree == 2)
        #expect(bp.vDegree == 2)
    }

    @Test func getPoleAndSet() throws {
        let bp = try #require(makeBezierSurface()).bezierProperties
        #expect(bp.pole(uIndex: 1, vIndex: 1) == SIMD3(0, 0, 0))
        // Row 1 of the net is U index 1, so (1, 2) is its second entry, not the second row's first.
        #expect(bp.pole(uIndex: 1, vIndex: 2) == SIMD3(0, 5, 1))
        let ok = bp.setPole(uIndex: 1, vIndex: 1, point: SIMD3(1, 2, 3))
        #expect(ok)
        #expect(bp.pole(uIndex: 1, vIndex: 1) == SIMD3(1, 2, 3))
    }

    @Test func rationalFlags() throws {
        let bp = try #require(makeBezierSurface()).bezierProperties
        // Non-rational by default
        #expect(!bp.isURational)
        #expect(!bp.isVRational)
    }

    @Test func exchangeUV() throws {
        let bp = try #require(makeBezierSurface()).bezierProperties
        #expect(bp.pole(uIndex: 1, vIndex: 2) == SIMD3(0, 5, 1))
        let ok = bp.exchangeUV()
        #expect(ok)
        #expect(bp.uDegree == 2)
        #expect(bp.vDegree == 2)
        // The degrees cannot show a transpose of a 2 x 2-degree net; the poles can.
        #expect(bp.pole(uIndex: 1, vIndex: 2) == SIMD3(5, 0, 1))
        #expect(bp.pole(uIndex: 2, vIndex: 1) == SIMD3(0, 5, 1))
    }
}
