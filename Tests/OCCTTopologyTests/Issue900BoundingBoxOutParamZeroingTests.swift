import Testing
import simd
import OCCTBridge
@testable import OCCTSwift

/// PR #901 review, finding 1: `OCCTShapeBoundingBox`/`OCCTShapeBoundingBoxOptimal` (the bridge
/// functions #900 changed from `void`- to `bool`-returning, backed by `Bnd_Box::IsVoid()`) have
/// three failure paths — null shape, void box, and a caught OCCT exception — that all return
/// `false` before ever calling `Bnd_Box::Get(...)`. `OCCTBridge_Topology.h` still declares all six
/// out-parameters `_Nonnull`, so a caller that reads them without gating on the `bool` return would
/// see whatever was already on the stack, not a deterministic value. This suite calls the C bridge
/// functions directly — bypassing `Shape.boundingBox`/`boundingBoxOptimal(useShapeTolerance:)`,
/// which already gate correctly on the `bool` and would never observe this either way — with the
/// six out-locals pre-poisoned to a value the fix could never produce by chance, and confirms they
/// come back exactly zero.
///
/// A second review round (comment 3773896568) found the null-shape path specifically wasn't
/// covered: the fix that added this suite zeroed inside `occtComputeBoundingBox`, but both public
/// functions' own `if (!shape || !xmin || ...) return false;` guard short-circuited before ever
/// reaching it, so a null `shape` with valid out-pointers still returned untouched garbage.
/// `OCCTBridge_Topology.h` declares `shape` `_Nonnull`, so Swift refuses to pass `nil` directly —
/// `unsafeBitCast` is used below to synthesize a zero-bit-pattern `OCCTShapeRef` that type-checks
/// as non-optional but is a genuine null pointer at the ABI level, the same thing a non-Swift
/// caller violating the `_Nonnull` contract would hand across.
@Suite("Issue #900 review: boundingBox out-params are zeroed on failure, not left uninitialized")
struct Issue900BoundingBoxOutParamZeroingTests {

    /// A far-disjoint intersection is the reliable way to get a genuinely void `Shape` (matching
    /// `OCCTAnalysisTests.voidShapeReportsNoBoxFromAnyAccessor`'s fixture) --
    /// `Shape.compound([])` refuses to construct at all.
    private func makeVoidShape() throws -> Shape {
        let b1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b2 = try #require(
            Shape.box(origin: SIMD3(1000, 1000, 1000), width: 10, height: 10, depth: 10))
        return try #require(b1.intersection(b2))
    }

    @Test func plainBoundingBoxZeroesOutParamsOnVoidShape() throws {
        let voidShape = try makeVoidShape()

        var xmin = -999.0, ymin = -999.0, zmin = -999.0
        var xmax = -999.0, ymax = -999.0, zmax = -999.0
        let ok = OCCTShapeBoundingBox(voidShape.handle, &xmin, &ymin, &zmin, &xmax, &ymax, &zmax)

        #expect(!ok)
        #expect(xmin == 0.0)
        #expect(ymin == 0.0)
        #expect(zmin == 0.0)
        #expect(xmax == 0.0)
        #expect(ymax == 0.0)
        #expect(zmax == 0.0)
    }

    @Test func optimalBoundingBoxZeroesOutParamsOnVoidShape() throws {
        let voidShape = try makeVoidShape()

        var xmin = -999.0, ymin = -999.0, zmin = -999.0
        var xmax = -999.0, ymax = -999.0, zmax = -999.0
        let ok = OCCTShapeBoundingBoxOptimal(
            voidShape.handle, false, &xmin, &ymin, &zmin, &xmax, &ymax, &zmax)

        #expect(!ok)
        #expect(xmin == 0.0)
        #expect(ymin == 0.0)
        #expect(zmin == 0.0)
        #expect(xmax == 0.0)
        #expect(ymax == 0.0)
        #expect(zmax == 0.0)
    }

    @Test func plainBoundingBoxZeroesOutParamsOnNullShape() throws {
        let nullShape: OCCTShapeRef = unsafeBitCast(UInt(0), to: OCCTShapeRef.self)

        var xmin = -999.0, ymin = -999.0, zmin = -999.0
        var xmax = -999.0, ymax = -999.0, zmax = -999.0
        let ok = OCCTShapeBoundingBox(nullShape, &xmin, &ymin, &zmin, &xmax, &ymax, &zmax)

        #expect(!ok)
        #expect(xmin == 0.0)
        #expect(ymin == 0.0)
        #expect(zmin == 0.0)
        #expect(xmax == 0.0)
        #expect(ymax == 0.0)
        #expect(zmax == 0.0)
    }

    @Test func optimalBoundingBoxZeroesOutParamsOnNullShape() throws {
        let nullShape: OCCTShapeRef = unsafeBitCast(UInt(0), to: OCCTShapeRef.self)

        var xmin = -999.0, ymin = -999.0, zmin = -999.0
        var xmax = -999.0, ymax = -999.0, zmax = -999.0
        let ok = OCCTShapeBoundingBoxOptimal(
            nullShape, false, &xmin, &ymin, &zmin, &xmax, &ymax, &zmax)

        #expect(!ok)
        #expect(xmin == 0.0)
        #expect(ymin == 0.0)
        #expect(zmin == 0.0)
        #expect(xmax == 0.0)
        #expect(ymax == 0.0)
        #expect(zmax == 0.0)
    }
}
