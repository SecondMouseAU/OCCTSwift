import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.129.0: BSplineCurve LocalD, BSplineSurface completions, BezierSurface completions

// Every value is Geom_BSplineCurve's on the same interpolated curve at u = 0.5 with the same knot
// span (Scripts/repro/766-curve-bspline-v121-locald/transcript.txt). The earlier versions wrapped
// each body in `if let` and compared one Local* call against another, so a defect shared by both
// passed, and localD1 asserted only a non-zero tangent (#766).
@Suite("BSplineCurve3D LocalD v129")
struct BSplineCurve3DLocalDTests {
    private static let points: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(3, 1, 0), SIMD3(5, 3, 0),
    ]
    private static let p = SIMD3<Double>(0.072106451694934875, 0.95695460206689964, 0)
    private static let d1 = SIMD3<Double>(0.2477669679230789, 1.5575211306967534, 0)
    private static let d2 = SIMD3<Double>(0.395452364913007, -1.3532395046896071, 0)
    private static let d3 = SIMD3<Double>(-0.11258335931896467, 0.43387673435137636, 0)

    private static func curve() -> Curve3D? {
        let c = Curve3D.interpolate(points: points)
        if c == nil { Issue.record("interpolated curve not built") }
        return c
    }

    private static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        simd_distance(a, b) < 1e-12
    }

    @Test("LocalD0 matches LocalValue")
    func localD0() {
        guard let curve = Self.curve() else { return }
        let k = curve.bsplineLocateU(0.5)
        let val = curve.bsplineLocalValue(u: 0.5, fromKnot: k, toKnot: k + 1)
        let d0 = curve.bsplineLocalD0(u: 0.5, fromKnot: k, toKnot: k + 1)
        #expect(Self.near(val, d0))
        #expect(Self.near(val, Self.p))
        #expect(Self.near(d0, Self.p))
    }

    @Test("LocalD1 returns point + tangent")
    func localD1() {
        guard let curve = Self.curve() else { return }
        let k = curve.bsplineLocateU(0.5)
        let result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
        #expect(Self.near(result.point, Self.p))
        #expect(Self.near(result.d1, Self.d1))
    }

    @Test("LocalD2 returns curvature information")
    func localD2() {
        guard let curve = Self.curve() else { return }
        let k = curve.bsplineLocateU(0.5)
        let result = curve.bsplineLocalD2(u: 0.5, fromKnot: k, toKnot: k + 1)
        #expect(Self.near(result.point, Self.p))
        #expect(Self.near(result.d1, Self.d1))
        #expect(Self.near(result.d2, Self.d2))
    }

    @Test("LocalD3 returns all derivatives")
    func localD3() {
        guard let curve = Self.curve() else { return }
        let k = curve.bsplineLocateU(0.5)
        let result = curve.bsplineLocalD3(u: 0.5, fromKnot: k, toKnot: k + 1)
        #expect(Self.near(result.point, Self.p))
        #expect(Self.near(result.d1, Self.d1))
        #expect(Self.near(result.d2, Self.d2))
        #expect(Self.near(result.d3, Self.d3))
    }

    @Test("LocalDN matches D1 for n=1")
    func localDN() {
        guard let curve = Self.curve() else { return }
        let k = curve.bsplineLocateU(0.5)
        let dn1 = curve.bsplineLocalDN(u: 0.5, fromKnot: k, toKnot: k + 1, n: 1)
        let d1result = curve.bsplineLocalD1(u: 0.5, fromKnot: k, toKnot: k + 1)
        #expect(Self.near(dn1, d1result.d1))
        #expect(Self.near(dn1, Self.d1))
    }
}
