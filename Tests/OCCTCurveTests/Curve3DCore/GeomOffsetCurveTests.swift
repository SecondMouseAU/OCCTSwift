import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_OffsetCurve Tests")
struct GeomOffsetCurveTests {
    @Test func createFromLine() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            return
        }
        if let offset = Curve3D.offset(basis: line, offset: 5.0, dirX: 0, dirY: 0, dirZ: 1) {
            #expect(abs(offset.offsetValue - 5.0) < 1e-10)
        }
    }

    @Test func offsetDirection() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            return
        }
        if let offset = Curve3D.offset(basis: line, offset: 5.0, dirX: 0, dirY: 0, dirZ: 1) {
            if let dir = offset.offsetDirection {
                #expect(abs(dir.z - 1.0) < 1e-10)
            }
        }
    }
}
