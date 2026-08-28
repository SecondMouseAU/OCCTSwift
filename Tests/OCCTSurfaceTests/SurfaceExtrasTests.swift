import Testing

@testable import OCCTSwift

@Suite("Surface Extras v0.109")
struct SurfaceExtrasTests {
    @Test func surfaceBounds() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)  // TopAbs_FACE
            if faces.count > 0 {
                if let surf = faces[0].extractFaceSurface() {
                    let b = surf.parameterBounds
                    // Should have finite bounds for a box face
                    #expect(b.uMax > b.uMin)
                    #expect(b.vMax > b.vMin)
                }
            }
        }
    }

    @Test func planeContinuityClass() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let surf = faces[0].extractFaceSurface() {
                    // Geom_Plane is analytic, so infinitely differentiable.
                    #expect(surf.continuityClass == .cN)
                    #expect(surf.continuityClass.satisfies(.c2))
                }
            }
        }
    }

    @Test func copySurface() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let surf = faces[0].extractFaceSurface() {
                    if let copy = surf.copy() {
                        let b1 = surf.parameterBounds
                        let b2 = copy.parameterBounds
                        // Bounds should match
                        #expect(abs(b1.uMin - b2.uMin) < 1e-6)
                    }
                }
            }
        }
    }
}
