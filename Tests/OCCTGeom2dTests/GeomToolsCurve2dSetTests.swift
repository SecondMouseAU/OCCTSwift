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
}
