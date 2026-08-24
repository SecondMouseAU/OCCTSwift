import Testing
import simd

@testable import OCCTSwift

/// #833: `maxTolerance(type:)`/`minTolerance(type:)`/`avgTolerance(type:)` (backed by
/// `ShapeAnalysis_ShapeTolerance`) used a compressed `Int` encoding (`0`=vertex, `1`=edge,
/// `2`=face, anything else = all sub-shapes) that silently disagreed with the unrelated
/// `maxTolerance(subShapeType:)` (backed by `BRep_Tool::MaxTolerance`), whose `Int` is the real
/// `TopAbs_ShapeEnum` ordinal (`2`=SOLID, `4`=FACE, `6`=EDGE, `7`=VERTEX). A caller who learned one
/// convention and called the other with the same `Int` silently measured the wrong sub-shape kind.
///
/// Fix: additive `ShapeType`-typed overloads on the `type:`-based trio, which pass the caller's
/// `ShapeType` straight through as the real `TopAbs_ShapeEnum` ordinal, the same convention
/// `maxTolerance(subShapeType:)` already used, so both typed, unambiguous entry points agree.
@Suite("Issue #833: maxTolerance/minTolerance/avgTolerance encoding")
struct Issue833MaxToleranceEncodingTests {

    /// Documents the actual, historical divergence this issue reports: the same literal `2`
    /// means FACE under `maxTolerance(type:)`'s convention and `TopAbs_SOLID` (which
    /// `BRep_Tool::MaxTolerance` never measures, so it silently reports 0) under
    /// `maxTolerance(subShapeType:)`'s convention.
    @Test("legacy Int(type:) and Int(subShapeType:) disagree on the same literal 2")
    func legacyIntConventionsDisagreeOnTheSameLiteral() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // "2" under maxTolerance(type:)'s compressed convention is FACE, and a fresh box has a
        // real, non-zero face tolerance (Precision::Confusion(), ~1e-7).
        let faceTolerance = box.maxTolerance(type: 2)
        #expect(faceTolerance > 0)

        // "2" under maxTolerance(subShapeType:)'s convention is TopAbs_SOLID.
        // BRep_Tool::MaxTolerance only ever measures VERTEX/EDGE/FACE and returns 0 for anything
        // else -- including SOLID -- so this is always 0, regardless of the box's own tolerances.
        let solidTolerance = box.maxTolerance(subShapeType: 2)
        #expect(solidTolerance == 0)

        // The same literal answers two different questions depending which overload it's passed
        // to -- exactly the failure scenario #833 reports.
        #expect(faceTolerance != solidTolerance)
    }

    /// The new `ShapeType`-typed overloads must agree exactly with the legacy `Int` overloads for
    /// the three values the legacy encoding actually supports (vertex/edge/face) -- proving the
    /// additive overload is a pure convention change, not a different computation.
    @Test("ShapeType overload matches legacy Int overload for vertex/edge/face")
    func typedOverloadMatchesLegacyForSharedCases() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        #expect(box.maxTolerance(type: .vertex) == box.maxTolerance(type: 0))
        #expect(box.maxTolerance(type: .edge) == box.maxTolerance(type: 1))
        #expect(box.maxTolerance(type: .face) == box.maxTolerance(type: 2))

        #expect(box.minTolerance(type: .vertex) == box.minTolerance(type: 0))
        #expect(box.minTolerance(type: .edge) == box.minTolerance(type: 1))
        #expect(box.minTolerance(type: .face) == box.minTolerance(type: 2))

        #expect(box.avgTolerance(type: .vertex) == box.avgTolerance(type: 0))
        #expect(box.avgTolerance(type: .edge) == box.avgTolerance(type: 1))
        #expect(box.avgTolerance(type: .face) == box.avgTolerance(type: 2))
    }

    /// The new `ShapeType`-typed overload must agree with `maxTolerance(subShapeType:)` (a
    /// DIFFERENT OCCT entry point, `BRep_Tool::MaxTolerance`) for the ordinals that name the
    /// same sub-shape kind under both conventions: proves the typed overload's convention is the
    /// real `TopAbs_ShapeEnum` ordinal, not the legacy compressed one. Both algorithms compute the
    /// same quantity the same way -- the max of each matching sub-shape's own `BRep_Tool::
    /// Tolerance()` -- so they must agree at any tolerance value, not only the default.
    @Test("ShapeType overload agrees with maxTolerance(subShapeType:)'s ordinal convention")
    func typedOverloadAgreesWithSubShapeTypeConvention() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // At the box's default (fresh construction) tolerances:
        #expect(box.maxTolerance(type: .vertex) == box.maxTolerance(subShapeType: 7))  // TopAbs_VERTEX
        #expect(box.maxTolerance(type: .edge) == box.maxTolerance(subShapeType: 6))  // TopAbs_EDGE
        #expect(box.maxTolerance(type: .face) == box.maxTolerance(subShapeType: 4))  // TopAbs_FACE

        // And again after forcing every sub-shape's tolerance to a distinguishable, non-default
        // value -- ruling out the two agreeing only by coincidence at Precision::Confusion().
        let forced = 0.01
        box.setTolerance(forced)
        #expect(abs(box.maxTolerance(type: .edge) - forced) < 1e-9)
        #expect(box.maxTolerance(type: .edge) == box.maxTolerance(subShapeType: 6))
        #expect(box.maxTolerance(type: .face) == box.maxTolerance(subShapeType: 4))
        #expect(box.maxTolerance(type: .vertex) == box.maxTolerance(subShapeType: 7))
    }
}
