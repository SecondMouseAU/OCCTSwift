import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_OffsetCurve Basis Tests")
struct OffsetCurveBasisTests {

    private func expectPoint(
        _ got: SIMD3<Double>, _ want: SIMD3<Double>, _ what: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            simd_distance(got, want) < 1e-9, "\(what): got \(got), want \(want)",
            sourceLocation: sourceLocation)
    }

    /// The basis of an offset curve is the curve it was built from, not the offset itself.
    ///
    /// `Geom_OffsetCurve.hxx` gives `Value(U) = C(U) + Offset * (T ^ V) / ||T ^ V||`, so an
    /// offset of 2 from the X axis about a Z reference direction sits at `T ^ V = (1,0,0) ^
    /// (0,0,1) = (0,-1,0)`, two units to -Y. The basis evaluates on the axis itself.
    @Test func getBasisCurve() throws {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let offset = try #require(
            Curve3D.offset(basis: line, offset: 2.0, dirX: 0, dirY: 0, dirZ: 1))
        // The control that the offset really is offset, so the basis below is not the same curve.
        expectPoint(offset.point(at: 3), SIMD3(3, -2, 0), "offset point")
        let basis = try #require(offset.offsetBasisCurve, "an offset curve has a basis")
        expectPoint(basis.point(at: 3), SIMD3(3, 0, 0), "basis point at 3")
        expectPoint(basis.point(at: 7), SIMD3(7, 0, 0), "basis point at 7")
        // Along the line's own direction, which a basis with another direction would not share.
        expectPoint(basis.point(at: 7) - basis.point(at: 3), SIMD3(4, 0, 0), "basis direction")
    }

    @Test func getBasisCurveOfACircleKeepsItsRadiusAndCentre() throws {
        let circle = try #require(
            Curve3D.circle(center: SIMD3(1, 2, 3), normal: SIMD3(0, 0, 1), radius: 5))
        let offset = try #require(
            Curve3D.offset(basis: circle, offset: 1.5, dirX: 0, dirY: 0, dirZ: 1))
        // T ^ V at parameter 0 is (0,1,0) ^ (0,0,1) = (1,0,0): outwards, so radius 6.5.
        expectPoint(offset.point(at: 0), SIMD3(7.5, 2, 3), "offset point")
        let basis = try #require(offset.offsetBasisCurve)
        #expect(basis.circleProperties.radius == 5)
        expectPoint(basis.point(at: 0), SIMD3(6, 2, 3), "basis start")
        expectPoint(basis.point(at: .pi / 2), SIMD3(1, 7, 3), "basis quarter turn")
    }

    @Test func nonOffsetCurveReturnsNil() throws {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        #expect(line.offsetBasisCurve == nil)
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        #expect(circle.offsetBasisCurve == nil)
        // The control that makes nil mean "not an offset curve": an offset of the same line has
        // a basis.
        let offset = try #require(
            Curve3D.offset(basis: line, offset: 2.0, dirX: 0, dirY: 0, dirZ: 1))
        #expect(offset.offsetBasisCurve != nil)
    }
}
