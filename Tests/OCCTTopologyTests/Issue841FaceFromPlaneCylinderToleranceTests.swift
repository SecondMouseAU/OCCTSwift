import Testing
import simd
@testable import OCCTSwift

/// #841: `Shape.faceFromPlane`/`faceFromCylinder` were duplicated as two unrelated static-factory
/// pairs -- one (`uRange`/`vRange`) taking an explicit `tolerance`, driving `BRepLib_MakeFace`
/// directly; the other (`uBounds`/`vBounds`) with NO tolerance parameter at all, driving
/// `BRepBuilderAPI_MakeFace`'s tolerance-less constructor, which hardcodes `Precision::Confusion()`
/// (`1e-7`) internally. Fixed by having the `uBounds`/`vBounds` pair delegate to the
/// `uRange`/`vRange` pair with an additive `tolerance` parameter defaulting to that same `1e-7`,
/// so existing callers see byte-identical geometry and new callers can control the tolerance.
@Suite("Issue #841: faceFromPlane/faceFromCylinder tolerance consolidation")
struct Issue841FaceFromPlaneCylinderToleranceTests {

    /// `uBounds`/`vBounds` deliberately different extents: a swapped `uRange`/`vRange` argument
    /// in the delegation would produce a visibly different bounding box, so this genuinely
    /// exercises the delegation's argument order, not just that both calls return non-nil.
    /// (`tolerance` itself has no observable effect on this geometry -- `BRepLib_MakeFace::Init`
    /// always builds the face at `Precision::Confusion()` regardless of the caller's `TolDegen`;
    /// that parameter only matters for degenerate-curve collapse, which a plain rectangle never
    /// reaches. What this test actually proves is that the two overloads drive the identical
    /// `BRepLib_MakeFace` call with the identical arguments, which is the substance of #841.)
    @Test("faceFromPlane's uBounds overload matches the uRange overload")
    func faceFromPlaneDelegatesWithMatchingDefault() throws {
        let origin = SIMD3<Double>(1, 2, 3)
        let normal = SIMD3<Double>(0, 0, 1)
        let uBounds = 0.0...10.0
        let vBounds = 0.0...25.0

        let viaBounds = try #require(
            Shape.faceFromPlane(origin: origin, normal: normal, uBounds: uBounds, vBounds: vBounds))
        let viaRange = try #require(
            Shape.faceFromPlane(origin: origin, normal: normal, uRange: uBounds, vRange: vBounds, tolerance: 1e-7))

        let boundsBox = viaBounds.boundingBox
        let rangeBox = viaRange.boundingBox
        #expect(boundsBox != nil && rangeBox != nil)
        if let b = boundsBox, let r = rangeBox {
            #expect(simd_length(b.min - r.min) < 1e-9)
            #expect(simd_length(b.max - r.max) < 1e-9)
        }
    }

    @Test("faceFromCylinder's uBounds overload matches the uRange overload at Precision::Confusion()")
    func faceFromCylinderDelegatesWithMatchingDefault() throws {
        let origin = SIMD3<Double>.zero
        let axis = SIMD3<Double>(0, 0, 1)
        let radius = 5.0
        let uBounds = 0.0...(2 * Double.pi)
        let vBounds = 0.0...10.0

        let viaBounds = try #require(
            Shape.faceFromCylinder(origin: origin, axis: axis, radius: radius, uBounds: uBounds, vBounds: vBounds))
        let viaRange = try #require(
            Shape.faceFromCylinder(origin: origin, axis: axis, radius: radius, uRange: uBounds, vRange: vBounds, tolerance: 1e-7))

        let boundsBox = viaBounds.boundingBox
        let rangeBox = viaRange.boundingBox
        #expect(boundsBox != nil && rangeBox != nil)
        if let b = boundsBox, let r = rangeBox {
            #expect(simd_length(b.min - r.min) < 1e-9)
            #expect(simd_length(b.max - r.max) < 1e-9)
        }
    }

    /// The new `tolerance` parameter is real, not decorative: the `uBounds`/`vBounds` overload
    /// must accept an explicit, non-default tolerance and still succeed.
    @Test("faceFromPlane/faceFromCylinder's uBounds overloads accept an explicit tolerance")
    func explicitToleranceIsAccepted() throws {
        let plane = Shape.faceFromPlane(uBounds: 0...10, vBounds: 0...10, tolerance: 1e-4)
        #expect(plane != nil)
        let cylinder = Shape.faceFromCylinder(radius: 5, uBounds: 0...(2 * Double.pi), vBounds: 0...10, tolerance: 1e-4)
        #expect(cylinder != nil)
    }
}
