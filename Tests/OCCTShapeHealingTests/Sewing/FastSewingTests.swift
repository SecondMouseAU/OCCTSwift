import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Fast Sewing")
struct FastSewingTests {
    // #1475: `BRepBuilderAPI_FastSewing`'s own header says it "supposes that all surfaces are
    // finite and are naturally restricted by their bounds" -- a sphere's single spherical face
    // qualifies (naturally bounded), a box's six trimmed-`Geom_Plane` faces do not (`Add()`
    // returns false for all six, `Perform()` sees an empty face list). So the "valid" fixture
    // here is a sphere, not the box every other suite in this target uses. Asserts real geometry
    // survived, not just non-nilness: the previous version of this test used a box and only
    // checked `sewn != nil`, which passed even while `OCCTShapeFastSewn` was wrapping an empty
    // `TopoDS_Shape` in a non-nil handle (the #1475 defect).
    @Test("Fast sew a valid shape")
    func fastSewValid() {
        let sphere = Shape.sphere(radius: 10)!
        let sewn = sphere.fastSewn()
        #expect(sewn != nil)
        if let sewn {
            #expect(sewn.faces().count == 1)
            // `.volume` needs `Shape.Closed()` set on the enclosing shell, which
            // `BRepBuilderAPI_FastSewing` does not set even for a geometrically-closed single-face
            // sphere (confirmed directly against the kernel: `BRepGProp::VolumeProperties(...,
            // OnlyClosed: true)` reports 0 here). `.surfaceArea` has no such closedness
            // requirement and is the measurement that actually distinguishes real geometry from
            // an empty result.
            if let area = sewn.surfaceArea {
                let expected = 4.0 * Double.pi * pow(10, 2)
                #expect(abs(area - expected) < 1.0)
            } else {
                Issue.record("fastSewn() result on a sphere has no computable surface area")
            }
        }
    }

    @Test("Fast sew with custom tolerance")
    func fastSewTolerance() {
        let sphere = Shape.sphere(radius: 10)!
        let sewn = sphere.fastSewn(tolerance: 0.01)
        #expect(sewn != nil)
        if let sewn {
            #expect(sewn.faces().count == 1)
        }
    }

    // Regression guard for #1475: `BRepBuilderAPI_FastSewing::Add()` declines a face whose
    // surface fails `IsInfinite()` on its own natural `Bounds()`, which is what an ordinary
    // planar `TopoDS_Face` has (a box face's surface is a raw, untrimmed `Geom_Plane` with the
    // real extent carried by its wire, not the surface). For a plain box `Add()` returns false
    // for all 6 faces and `GetResult()` is a null `TopoDS_Shape`. `OCCTShapeFastSewn` used to
    // wrap that null shape in a non-nil `OCCTShapeRef` and report success regardless;
    // `fastSewn()` must genuinely return nil here, matching its own doc ("Returns: The sewn
    // shape, or nil on failure").
    @Test("Fast sew declines a box (faces are not naturally bounded)")
    func fastSewBoxReturnsNil() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.fastSewn()
        #expect(sewn == nil)
    }
}
