import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #748: networkSurface transposed two corners and reported .done

/// The four corners of a network surface are pinned by the input curves' own endpoints, so the
/// expected values need no derivation and no tolerance argument. That makes a corner check the
/// cheapest regression test this API can carry, and it would have caught #748 at any point in the
/// API's life.
///
/// The non-square case is the one that matters. A square network cannot detect an axis swap as a
/// shape error, because the swapped grid still has the right dimensions: it builds, reports `.done`
/// and returns a surface whose two off-diagonal corners are exactly point-reflected. That is how
/// #748 shipped, and why a 2x2 fixture was not enough. On a 2x3 the same bug fails `Init` outright.
@Suite("networkSurface places every corner where its input curves say (#748)")
struct Issue748NetworkSurfaceCornersTests {

    private static func seg(_ a: SIMD3<Double>, _ b: SIMD3<Double>) throws -> Curve3D {
        try #require(Curve3D.segment(from: a, to: b))
    }

    private static func cornersMatch(_ s: Surface, _ expected: [SIMD3<Double>]) -> Int {
        let d = s.domain
        let got = [
            s.point(atU: d.uMin, v: d.vMin), s.point(atU: d.uMax, v: d.vMin),
            s.point(atU: d.uMin, v: d.vMax), s.point(atU: d.uMax, v: d.vMax),
        ]
        var wrong = 0
        for (i, e) in expected.enumerated() {
            let dx = got[i].x - e.x
            let dy = got[i].y - e.y
            let dz = got[i].z - e.z
            if (dx * dx + dy * dy + dz * dz).squareRoot() > 1e-6 { wrong += 1 }
        }
        return wrong
    }

    @Test("a square 2x2 network puts all four corners where the curves do")
    func squareNetworkCornersAreExact() throws {
        let p0 = try Self.seg(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let p1 = try Self.seg(SIMD3(0, 10, 0), SIMD3(10, 10, 0))
        let g0 = try Self.seg(SIMD3(0, 0, 0), SIMD3(0, 10, 0))
        let g1 = try Self.seg(SIMD3(10, 0, 0), SIMD3(10, 10, 0))

        let (surface, status) = Surface.networkSurface(profiles: [p0, p1], guides: [g0, g1])
        #expect(status == .done)
        let s = try #require(surface)
        // Before the fix these were (0,10,0) and (10,0,0), each exactly where the other belongs,
        // sqrt(200) out, with .done reported.
        #expect(
            Self.cornersMatch(
                s,
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                    SIMD3(0, 10, 0), SIMD3(10, 10, 0),
                ]) == 0)
    }

    @Test("a non-square 2x3 network builds at all, which the swapped grid could not")
    func nonSquareNetworkBuilds() throws {
        let p0 = try Self.seg(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let p1 = try Self.seg(SIMD3(0, 10, 0), SIMD3(10, 10, 0))
        let g0 = try Self.seg(SIMD3(0, 0, 0), SIMD3(0, 10, 0))
        let g1 = try Self.seg(SIMD3(5, 0, 0), SIMD3(5, 10, 0))
        let g2 = try Self.seg(SIMD3(10, 0, 0), SIMD3(10, 10, 0))

        let (surface, status) = Surface.networkSurface(profiles: [p0, p1], guides: [g0, g1, g2])
        // Before the fix: .invalidInput and no surface, because the swapped grid is the wrong shape.
        #expect(status == .done)
        let s = try #require(surface)
        #expect(
            Self.cornersMatch(
                s,
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                    SIMD3(0, 10, 0), SIMD3(10, 10, 0),
                ]) == 0)
    }
}
