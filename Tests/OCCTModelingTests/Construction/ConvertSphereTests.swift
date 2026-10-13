import Testing

@testable import OCCTSwift

@Suite("Convert Sphere Tests")
struct ConvertSphereTests {

    @Test func sphereToBSpline() throws {
        let surface = try #require(
            Surface.fromSphere(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10))
        // GeomAbs_BSplineSurface is 6 in `surfaceType`'s numbering: the conversion happened.
        #expect(surface.surfaceType == 6)
        // The domain is the whole sphere: u over a full turn, v from pole to pole.
        let domain = surface.domain
        #expect(abs(domain.uMin) < 1e-12)
        #expect(abs(domain.uMax - 2 * Double.pi) < 1e-12)
        #expect(abs(domain.vMin + Double.pi / 2) < 1e-12)
        #expect(abs(domain.vMax - Double.pi / 2) < 1e-12)
        // The parameterisation starts at (r, 0, 0) and ends at the south pole (0, 0, -r).
        let origin = surface.point(atU: 0, v: 0)
        #expect(abs(origin.x - 10) < 1e-9 && abs(origin.y) < 1e-9 && abs(origin.z) < 1e-9)
        let south = surface.point(atU: 0, v: -Double.pi / 2)
        #expect(abs(south.z + 10) < 1e-9 && abs(south.x) < 1e-9 && abs(south.y) < 1e-9)
        let north = surface.point(atU: 0, v: Double.pi / 2)
        #expect(abs(north.z - 10) < 1e-9)
        // The conversion is a rational B-spline, whose parameter is not the angle, so only the
        // geometry is pinned: every sample stays on the sphere.
        for (u, v) in [(1.0, 0.5), (2.0, -0.7), (4.0, 1.2), (5.5, -1.4)] {
            let p = surface.point(atU: u, v: v)
            let radius = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
            #expect(abs(radius - 10) < 1e-6, "(\(u), \(v)) is \(radius) from the centre")
        }
    }
}
