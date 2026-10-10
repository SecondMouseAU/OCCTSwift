import Testing
import simd

@testable import OCCTSwift

@Suite("Geom_OffsetSurface Extension Tests")
struct GeomOffsetSurfaceExtTests {

    @Test func offsetValueRoundTrip() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        guard let off = plane.offset(distance: 5.0) else { return }
        #expect(abs(off.offsetValue - 5.0) < 1e-10)
    }

    @Test func setOffsetValue() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        guard let off = plane.offset(distance: 3.0) else { return }
        off.setOffsetValue(7.5)
        #expect(abs(off.offsetValue - 7.5) < 1e-10)
    }

    @Test func offsetBasisIsNotNil() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        guard let off = plane.offset(distance: 2.0) else { return }
        #expect(off.offsetBasis != nil)
        // #766: `!= nil` passed the offset surface handed back as its own basis. The basis is
        // the z = 0 plane: (1, 2) is (1, 2, 0) on it and (1, 2, 2) on the offset, see Scripts/repro/766-offset-plate-helix/.
        if let basis = off.offsetBasis {
            #expect(simd_length(basis.point(atU: 1, v: 2) - SIMD3(1, 2, 0)) < 1e-12)
            #expect(simd_length(off.point(atU: 1, v: 2) - SIMD3(1, 2, 2)) < 1e-12)
        }
    }

    @Test func nonOffsetSurfaceOffsetValueIsZero() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        // A plain plane has offsetValue == 0 (not an offset surface)
        #expect(abs(plane.offsetValue) < 1e-10)
    }

    @Test func nonOffsetSurfaceOffsetBasisIsNil() {
        guard let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            return
        }
        #expect(plane.offsetBasis == nil)
    }
}
