import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomTools_CurveSet Tests")
struct GeomToolsCurveSetTests {
    @Test func serializeDeserialize3D() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0)
        {
            if let data = Curve3D.serializeCurves([line, circ]) {
                #expect(!data.isEmpty)
                if let curves = Curve3D.deserializeCurves(data) {
                    #expect(curves.count == 2)
                }
            }
        }
    }

    @Test func roundtripPreservesGeometry() {
        if let circ = Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 7.0) {
            if let data = Curve3D.serializeCurves([circ]),
                let curves = Curve3D.deserializeCurves(data)
            {
                #expect(curves.count == 1)
            }
        }
    }
}
