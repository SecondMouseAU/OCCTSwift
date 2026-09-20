import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomTools_Curve2dSet Tests")
struct GeomToolsCurve2dSetTests {
    @Test func serializeDeserialize2D() {
        if let line = Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)),
            let circ = Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 3.0)
        {
            if let data = Curve2D.serializeCurves([line, circ]) {
                #expect(!data.isEmpty)
                if let curves = Curve2D.deserializeCurves(data) {
                    #expect(curves.count == 2)
                }
            }
        }
    }

    // #1512: GeomTools_Curve2dSet::Add dedups by underlying-object identity ("new or existing"
    // index), so two array elements sharing one underlying Geom2d_Curve used to be silently
    // collapsed to a single stored entry instead of refusing the batch. Passing the same
    // instance twice is the issue's own minimal fixture: both elements alias the identical
    // Geom2d_Curve handle.
    @Test func duplicateHandleRefusesTheBatch() {
        if let line = Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)) {
            #expect(Curve2D.serializeCurves([line, line]) == nil)
        }
    }
}
