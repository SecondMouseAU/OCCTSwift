import Foundation
import Testing
import simd

@testable import OCCTSwift

// Fixtures are required rather than `if let`-bound: an `if let` with no `else` passed with no
// assertion run at all when construction failed (#766).
@Suite("Geom_SweptSurface Properties")
struct GeomSwept3DTests {
    @Test func sweptDirection() throws {
        let line = try #require(Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)))
        let ext = try #require(Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)))
        let d = ext.sweptProperties.direction
        #expect(abs(d.z - 1) < 1e-6)
    }

    /// The basis curve of an extruded line is that line: a `Geom_Line` through the origin along
    /// +X, which is what `Geom_SweptSurface::BasisCurve` reports for this surface.
    ///
    /// This used to read `basis.domain` and assert nothing, so a nil or wrong basis curve passed.
    @Test func sweptBasisCurve() throws {
        let line = try #require(Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)))
        let ext = try #require(Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)))
        let basis = try #require(ext.sweptProperties.basisCurve)
        let loc = basis.lineProperties.location
        let dir = basis.lineProperties.direction
        #expect(simd_length(loc) < 1e-12)
        #expect(abs(dir.x - 1) < 1e-12)
        #expect(abs(dir.y) < 1e-12)
        #expect(abs(dir.z) < 1e-12)
    }
}
