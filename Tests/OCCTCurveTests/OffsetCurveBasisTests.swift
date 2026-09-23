import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_OffsetCurve Basis Tests")
struct OffsetCurveBasisTests {

    @Test func getBasisCurve() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("could not build the line")  // #766: was a silent return
            return
        }
        guard
            let offset = Curve3D.offset(
                basis: line, offset: 2.0,
                dirX: 0, dirY: 0, dirZ: 1)
        else {
            Issue.record("could not build the offset curve")  // #766: was a silent return
            return
        }
        // #766: this asserted nothing (`_ = basis`). The basis is the line itself: (3, 0, 0) at
        // parameter 3, while the offset curve sits 2 away along tangent x Z = -Y
        // (Geom_OffsetCurve, Scripts/repro/766-curve-offset-pointstobspline).
        if let basis = offset.offsetBasisCurve {
            #expect(simd_distance(basis.point(at: 3), SIMD3(3, 0, 0)) < 1e-9)
            #expect(simd_distance(offset.point(at: 3), SIMD3(3, -2, 0)) < 1e-9)
        } else {
            Issue.record("offsetBasisCurve was nil on an offset curve")
        }
    }

    @Test func nonOffsetCurveReturnsNil() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            return
        }
        #expect(line.offsetBasisCurve == nil)
    }
}
