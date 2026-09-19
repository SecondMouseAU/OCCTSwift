import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1424: `OCCTBndLibFace` (`Sources/OCCTBridge/src/OCCTBridge_Spatial_Bounding.mm`) had no
/// `occtShapeIsPresent(shape)` guard and no raw-pointer null check at all, unlike its sibling
/// `OCCTBndLibEdge` immediately above it. A genuinely-null `OCCTShapeRef` dereferenced
/// `shape->shape` directly, an unguarded C-struct-pointer access -- a crash unconditionally, with
/// no OCCT call involved yet. `Shape.handle` is non-optional, so this path isn't reachable
/// through the public Swift API. `OCCTBridge_Spatial.h` declares `shape` `_Nonnull`, so Swift
/// refuses to pass `nil` directly (unlike Issue #870's `OCCTShapeExtendShapeType`, whose
/// parameter isn't marked `_Nonnull`); `unsafeBitCast` synthesizes a zero-bit-pattern
/// `OCCTShapeRef` that type-checks as non-optional but is a genuine null pointer at the ABI
/// level, matching Issue #900's `OCCTShapeBoundingBox` precedent.
///
/// The issue also flagged a lower-confidence secondary concern: whether a *nullified* `Shape`
/// (a real, non-null `OCCTShapeRef` wrapping a null `TopoDS_Shape`) crashes uncatchably in
/// `BRepAdaptor_Surface::Initialize`. Traced and settled empirically (ground-truth C++
/// reproducer against the pinned `Libraries/OCCT.xcframework`, not just read): it does NOT.
/// `TopoDS::Face` passes the null through (`TopoDS.hxx`'s `IsNull() ? false : ...` idiom),
/// `BRepAdaptor_Surface::Initialize` guards `F.IsNull()` and returns early leaving an empty
/// adaptor, and `BndLib_AddSurface::Add` routes through `GeomGridEval_Surface` -- a *different*,
/// defensive class that detects the null underlying `Geom_Surface` and falls back to an empty
/// `std::monostate` evaluator rather than evaluating -- so the `Bnd_Box` stays void and
/// `box.Get(...)` throws a catchable exception the function's existing `catch (...)` already
/// turns into the same zeroed fallback. `nullifiedShapeIsSafe` below documents that finding; it
/// passes identically with or without this PR's guard, since the pre-existing `catch` already
/// covered it -- unlike `nullRawPointerReturnsZeroedFallback`, it is not itself a regression test
/// for the fix.
@Suite("Issue #1424: OCCTBndLibFace null guard")
struct Issue1424BndLibFaceNullGuardTests {

    @Test("a null OCCTShapeRef returns the zeroed fallback, not a crash")
    func nullRawPointerReturnsZeroedFallback() {
        let nullShape: OCCTShapeRef = unsafeBitCast(UInt(0), to: OCCTShapeRef.self)
        var x0 = -1.0, y0 = -1.0, z0 = -1.0, x1 = -1.0, y1 = -1.0, z1 = -1.0
        OCCTBndLibFace(nullShape, 1e-4, &x0, &y0, &z0, &x1, &y1, &z1)
        #expect(x0 == 0)
        #expect(y0 == 0)
        #expect(z0 == 0)
        #expect(x1 == 0)
        #expect(y1 == 0)
        #expect(z1 == 0)
    }

    @Test("a nullified Shape (null TopoDS_Shape, non-null wrapper) is already safe -- not this PR's fix")
    func nullifiedShapeIsSafe() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nullShape = try #require(box.nullified)
        let b = BndLib.face(nullShape)
        #expect(b.min == SIMD3<Double>.zero)
        #expect(b.max == SIMD3<Double>.zero)
    }

    @Test("an ordinary face's bounding box is unaffected")
    func ordinaryFaceUnaffected() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let face = try #require(sphere.subShapes(ofType: .face).first)
        let b = BndLib.face(face)
        #expect(abs(b.min.x + 5) < 0.1)
        #expect(abs(b.max.x - 5) < 0.1)
    }
}
