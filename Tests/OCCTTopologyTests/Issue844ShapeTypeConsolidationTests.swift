import Testing
import simd
@testable import OCCTSwift

/// #844: four independent Swift mirrors of `TopAbs_ShapeEnum` with no shared source of truth --
/// the canonical `ShapeType` (`Sources/OCCTSwift/ShapeType.swift`), a local `Shape.TopAbs_ShapeEnum`
/// used only by `isSubShapeValid(type:at:)`, `Shape.ShapeFilterType` (`sortedCompound(type:)` /
/// `predominantShapeType()`), and `Selector.SubShapeType` (pick results) -- and the non-canonical
/// three had already drifted on case-name casing (`compsolid` vs `ShapeType`'s `compSolid`).
///
/// Fixed: `isSubShapeValid(type:at:)` now takes `ShapeType` directly, the local
/// `Shape.TopAbs_ShapeEnum` is deleted; `Shape.ShapeFilterType` is now a typealias for `ShapeType`
/// (its case set matched exactly once casing was fixed); `Selector.SubShapeType`'s case is renamed
/// `compSolid` to match (kept as its own type -- its extra `.shape = 8` case, `TopAbs_SHAPE`, has
/// no `ShapeType` counterpart, since `ShapeType` only ever names a concrete sub-shape kind).
@Suite("Issue #844: ShapeType / ShapeFilterType / TopAbs_ShapeEnum consolidation")
struct Issue844ShapeTypeConsolidationTests {

    @Test("isSubShapeValid(type:) takes the canonical ShapeType directly")
    func isSubShapeValidTakesShapeType() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Explicitly typed as ShapeType (not the deleted local Shape.TopAbs_ShapeEnum) --
        // compiles only if isSubShapeValid(type:)'s parameter really is ShapeType.
        let edgeType: ShapeType = .edge
        #expect(box.isSubShapeValid(type: edgeType, at: 0))

        // A box has no compSolid sub-shape; the canonical casing (`compSolid`, not the old
        // `compsolid`) must compile and answer false rather than crash or trap.
        #expect(!box.isSubShapeValid(type: .compSolid, at: 0))

        // Out-of-range index still refused, same as before the type change.
        #expect(!box.isSubShapeValid(type: .edge, at: 999))
    }

    @Test("ShapeFilterType is a typealias for ShapeType -- interchangeable with no conversion")
    func shapeFilterTypeIsShapeType() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let solid1 = Shape.box(width: 5, height: 5, depth: 5),
              let solid2 = Shape.box(width: 5, height: 5, depth: 5)?.translated(by: SIMD3(20, 0, 0)) else {
            Issue.record("failed to build compound fixture")
            return
        }
        let compound = try #require(Shape.compound([solid1, solid2]))

        // A plain ShapeType value, with no `ShapeFilterType(...)` conversion, passed directly to
        // sortedCompound(type:) -- compiles and runs only because ShapeFilterType IS ShapeType.
        let t: ShapeType = .solid
        let filtered = compound.sortedCompound(type: t)
        #expect(filtered != nil)

        // predominantShapeType() returns exactly what sortedCompound(type:) accepts, with the
        // canonical casing.
        let predominant = box.predominantShapeType()
        #expect(predominant == .solid)
    }

    @Test("Selector.SubShapeType.compSolid uses the canonical casing")
    func selectorSubShapeTypeCasing() {
        // Compiles only with the renamed case (#844 renamed compsolid -> compSolid); proves the
        // rename landed and the case is still reachable/usable.
        let t = Selector.SubShapeType.compSolid
        #expect(t.rawValue == 1)
        #expect(t != .solid)

        // The extra `.shape` case (TopAbs_SHAPE = 8) has no ShapeType counterpart -- this is why
        // SubShapeType stays its own type rather than becoming a ShapeType typealias.
        #expect(Selector.SubShapeType.shape.rawValue == 8)
    }
}
