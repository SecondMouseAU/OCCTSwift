import Testing

@testable import OCCTSwift

@Suite("Surface Extras v0.109")
struct SurfaceExtrasTests {

    // #766: each test nested its assertion three `if`s deep. Face 1 of the centred box is an
    // untrimmed Geom_Plane, so its bounds are the kernel's +-2e100, not the face's extent (the
    // old comment's "finite bounds" was wrong, and `uMax > uMin` could not tell). See
    // Scripts/repro/766-surface-draw-eval-extras/.
    private func boxFaceSurface() -> Surface? {
        let s = Shape.box(width: 10, height: 10, depth: 10)?.subShapes(ofType: .face).first?.extractFaceSurface()
        #expect(s != nil, "box face 1 surface")
        return s
    }
    @Test func surfaceBounds() {
        if let surf = boxFaceSurface() {
            let b = surf.parameterBounds
            #expect(b.uMax > b.uMin)
            #expect(b.vMax > b.vMin)
            #expect(b.uMin == -2e100 && b.uMax == 2e100 && b.vMin == -2e100 && b.vMax == 2e100)
        }
    }

    @Test func planeContinuityClass() {
        if let surf = boxFaceSurface() {
            // Geom_Plane is analytic, so infinitely differentiable.
            #expect(surf.continuityClass == .cN)
            #expect(surf.continuityClass.satisfies(.c2))
        }
    }

    @Test func copySurface() {
        if let surf = boxFaceSurface() {
            let copy = surf.copy()
            #expect(copy != nil)
            if let copy {
                let b1 = surf.parameterBounds
                let b2 = copy.parameterBounds
                // Bounds should match
                #expect(abs(b1.uMin - b2.uMin) < 1e-6)
                // and so should the geometry, which the bounds of an infinite plane cannot show
                #expect(copy.point(atU: 1, v: 2) == surf.point(atU: 1, v: 2))
                #expect(copy.point(atU: 1, v: 2) == SIMD3(-5, -7, -4))
            }
        }
    }
}
