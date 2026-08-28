import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_SweptSurface Properties")
struct GeomSwept3DTests {
    @Test func sweptDirection() {
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            if let ext = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)) {
                let d = ext.sweptProperties.direction
                #expect(abs(d.z - 1) < 1e-6)
            }
        }
    }

    @Test func sweptBasisCurve() {
        if let line = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)) {
            if let ext = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)) {
                if let basis = ext.sweptProperties.basisCurve {
                    let _ = basis.domain
                }
            }
        }
    }
}
