import Foundation
import Testing

@testable import OCCTSwift

@Suite("Geom_OffsetSurface Extension Tests")
struct GeomOffsetSurfaceExtTests {

    // #2983: each test escaped through `guard let ... else { return }`, so a nil plane or offset
    // passed having asserted nothing. Setup is required now. Offset values were also only read
    // back at one positive number; a negative offset and the geometry that moves with the value
    // are pinned too (measured on the z = 0 plane: the offset surface sits at z = value).
    private func makePlane() throws -> Surface {
        try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)), "plane")
    }

    @Test func offsetValueRoundTrip() throws {
        let plane = try makePlane()
        let off = try #require(plane.offset(distance: 5.0), "offset surface")
        #expect(abs(off.offsetValue - 5.0) < 1e-10)
        // The sign survives, and the value is not a constant.
        let neg = try #require(plane.offset(distance: -3.0), "negative offset surface")
        #expect(abs(neg.offsetValue - -3.0) < 1e-10)
        #expect(vectorLength(neg.point(atU: 1, v: 2) - SIMD3(1, 2, -3)) < 1e-12)
    }

    @Test func setOffsetValue() throws {
        let plane = try makePlane()
        let off = try #require(plane.offset(distance: 3.0), "offset surface")
        #expect(vectorLength(off.point(atU: 1, v: 2) - SIMD3(1, 2, 3)) < 1e-12)
        off.setOffsetValue(7.5)
        #expect(abs(off.offsetValue - 7.5) < 1e-10)
        // The surface itself moved to the new offset, not only the stored number, and the basis
        // stayed where it was.
        #expect(vectorLength(off.point(atU: 1, v: 2) - SIMD3(1, 2, 7.5)) < 1e-12)
        let basis = try #require(off.offsetBasis, "offset basis")
        #expect(vectorLength(basis.point(atU: 1, v: 2) - SIMD3(1, 2, 0)) < 1e-12)
    }

    @Test func offsetBasisIsNotNil() throws {
        let plane = try makePlane()
        let off = try #require(plane.offset(distance: 2.0), "offset surface")
        // #766: `!= nil` passed the offset surface handed back as its own basis. The basis is
        // the z = 0 plane: (1, 2) is (1, 2, 0) on it and (1, 2, 2) on the offset, see Scripts/repro/766-offset-plate-helix/.
        let basis = try #require(off.offsetBasis, "offset basis")
        #expect(vectorLength(basis.point(atU: 1, v: 2) - SIMD3(1, 2, 0)) < 1e-12)
        #expect(vectorLength(off.point(atU: 1, v: 2) - SIMD3(1, 2, 2)) < 1e-12)
    }

    @Test func nonOffsetSurfaceOffsetValueIsZero() throws {
        let plane = try makePlane()
        // A plain plane has offsetValue == 0 (not an offset surface). The control: the same
        // plane offset by 5 reads 5, so a constant-zero getter fails here.
        #expect(abs(plane.offsetValue) < 1e-10)
        let off = try #require(plane.offset(distance: 5.0), "offset surface")
        #expect(abs(off.offsetValue - 5.0) < 1e-10)
    }

    @Test func nonOffsetSurfaceOffsetBasisIsNil() throws {
        let plane = try makePlane()
        #expect(plane.offsetBasis == nil)
        // The control: an offset of the same plane does have a basis.
        let off = try #require(plane.offset(distance: 2.0), "offset surface")
        #expect(off.offsetBasis != nil)
    }
}
