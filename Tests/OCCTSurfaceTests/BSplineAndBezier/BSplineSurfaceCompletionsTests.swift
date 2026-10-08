import Testing
import simd

@testable import OCCTSwift

@Suite("v0.126.0, BSpline Surface completions")
struct BSplineSurfaceCompletionsTests {

    // #766: both tests sat inside four `if`s, the first checked only `m > 0` and only when the
    // list was non-empty, and the second asserted nothing at all. Face 1 of the NURBS-converted
    // centred 10-box is a Geom_BSplineSurface on [0, 10] x [-10, 0] with two knots of multiplicity 2 in
    // each direction, see Scripts/repro/766-pipe-findsurface-bspline/.
    private func firstNurbsFaceSurface() -> Surface? {
        Shape.box(width: 10, height: 10, depth: 10)?
            .nurbsConvertViaModifier()?
            .subShapes(ofType: .face).first?
            .faceSurfaceGeom()
    }
    @Test("U and V multiplicities")
    func multiplicities() {
        let surf = firstNurbsFaceSurface()
        #expect(surf != nil)
        if let surf {
            #expect(surf.bsplineUMultiplicities == [2, 2])
            #expect(surf.bsplineVMultiplicities == [2, 2])
        }
    }

    @Test("UReverse and VReverse don't crash")
    func reverse() {
        let surf = firstNurbsFaceSurface()
        #expect(surf != nil)
        if let surf {
            // Reversing a direction maps the point at u to u1 + u2 - u (domain [0, 10] x [-10, 0]).
            let before = surf.point(atU: 2, v: -3)
            #expect(simd_length(before - SIMD3(-5, -2, -3)) < 1e-12)
            #expect(surf.bsplineUReverse())
            #expect(simd_length(surf.point(atU: 8, v: -3) - before) < 1e-12)
            #expect(surf.bsplineVReverse())
            #expect(simd_length(surf.point(atU: 8, v: -7) - before) < 1e-12)
            // And the original parameters now name the point mirrored through the face centre.
            #expect(simd_length(surf.point(atU: 2, v: -3) - SIMD3(-5, 2, 3)) < 1e-12)
        }
    }
}
