import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomTools_Curve2dSet Tests")
struct GeomToolsCurve2dSetTests {
    @Test func serializeDeserialize2D() throws {
        // #1979: three nested `if let`s let a failed write or read pass, and only the count was
        // checked. The round trip through GeomTools_Curve2dSet keeps both curves: the line and
        // the radius-3 circle (Scripts/repro/766-geom2d-curveset-intana-misc/).
        let line = try #require(Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)))
        let circ = try #require(Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 3.0))
        let data = try #require(Curve2D.serializeCurves([line, circ]))
        #expect(!data.isEmpty)
        let curves = try #require(Curve2D.deserializeCurves(data))
        try #require(curves.count == 2)
        #expect(simd_distance(curves[0].point(at: 3), SIMD2(3, 0)) < 1e-12)
        #expect(abs(curves[1].circleProperties.radius - 3) < 1e-12)
    }

    // #1512: GeomTools_Curve2dSet::Add dedups by underlying-object identity ("new or existing"
    // index), so two array elements sharing one underlying Geom2d_Curve used to be silently
    // collapsed to a single stored entry instead of refusing the batch. Passing the same
    // instance twice is the issue's own minimal fixture: both elements alias the identical
    // Geom2d_Curve handle.
    @Test func duplicateHandleRefusesTheBatch() throws {
        let line = try #require(Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)))
        #expect(Curve2D.serializeCurves([line, line]) == nil)
    }
}
