import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1440 finding 1: `DiscretizeEdgeInto` (`Sources/OCCTBridge/src/OCCTBridge_Mesh.mm`, feeding
/// `Shape.edgePolyline(at:deflection:maxPoints:)` and `Shape.allEdgePolylines`) built
/// `GCPnts_TangentialDeflection` as `discretizer(curve, deflection, 0.1)`. The constructor's real
/// signature (`GCPnts_TangentialDeflection.hxx:77-82`) is
/// `(theC, theAngularDeflection /* radians */, theCurvatureDeflection /* linear */, ...)`, so the
/// caller's `deflection` -- documented everywhere on this API as the LINEAR/chordal tolerance --
/// landed in the ANGULAR slot, and the hardcoded `0.1` landed in the linear slot. Backwards.
///
/// This is only masked at the API's own default (`deflection: 0.1`, numerically coincident with
/// the hardcoded slot); any other value diverges from the documented contract.
///
/// The test builds a full-circle edge from a `Curve3D` via `Shape.edgeFromCurve(_:)` (full
/// domain, same underlying `Geom_Curve` handle `BRepAdaptor_Curve` evaluates), so
/// `Shape.edgePolyline` and `Curve3D.drawAdaptive` -- the file's own correctly-ordered sibling at
/// `OCCTBridge_Curve3D_Adaptor.mm:689` -- discretize the identical geometry. `drawAdaptive` takes
/// explicit, correctly-ordered `angularDeflection`/`chordalDeflection` parameters, so it serves as
/// the oracle for both the correct and the (deliberately) swapped call shape.
@Suite("Issue #1440: edgePolyline angular/linear deflection argument order")
struct Issue1440EdgeDeflectionArgumentOrderTests {

    /// A small chordal tolerance on a circle needs a modest point count (sagitta scales with
    /// `sqrt(tolerance / radius)`); the same number used as an ANGULAR tolerance instead needs a
    /// point roughly every `tolerance` radians, an order of magnitude more points for a full
    /// 2*pi turn. That asymmetry is what makes "used in the wrong slot" and "used in the right
    /// slot" produce dramatically different, easily distinguished point counts.
    @Test("edgePolyline's deflection argument lands in the linear slot, not the angular one")
    func deflectionIsLinearNotAngular() throws {
        let radius = 10.0
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius))
        let edge = try #require(Shape.edgeFromCurve(circle))

        let nonDefaultDeflection = 0.005
        let hardcodedSlotValue = 0.1

        // What the bridge actually returns for this edge at this deflection.
        let actual = try #require(
            edge.edgePolyline(at: 0, deflection: nonDefaultDeflection, maxPoints: 4000))

        // Oracle A: the CORRECT call shape (deflection in the linear/curvature slot, matching
        // the file's own correct sibling and this API's documented contract).
        let correct = circle.drawAdaptive(
            angularDeflection: hardcodedSlotValue,
            chordalDeflection: nonDefaultDeflection,
            maxPoints: 4000)

        // Oracle B: the BUGGY call shape (deflection in the angular slot instead).
        let buggy = circle.drawAdaptive(
            angularDeflection: nonDefaultDeflection,
            chordalDeflection: hardcodedSlotValue,
            maxPoints: 4000)

        // The fixture must actually distinguish the two call shapes, or this proves nothing
        // (okf/policies/prove-the-test-fails.md: "a matrix proves guards, not fixtures").
        #expect(
            buggy.count > correct.count * 3,
            "fixture doesn't separate correct (\(correct.count) pts) from buggy (\(buggy.count) pts) call shapes; pick a different deflection/radius"
        )

        // The actual bridge behavior must match the CORRECT oracle...
        #expect(
            actual.count == correct.count,
            "edgePolyline returned \(actual.count) points, expected \(correct.count) (the correctly-ordered oracle)"
        )
        // ...and must NOT match the buggy one (this is what fails pre-fix).
        #expect(
            actual.count != buggy.count,
            "edgePolyline returned \(actual.count) points, matching the SWAPPED-argument oracle (\(buggy.count)) -- the angular/linear argument order regressed"
        )

        // Point-for-point agreement with the correct oracle, not just a matching count.
        #expect(actual.count == correct.count)
        for (a, c) in zip(actual, correct) {
            #expect(abs(a.x - c.x) < 1e-9)
            #expect(abs(a.y - c.y) < 1e-9)
            #expect(abs(a.z - c.z) < 1e-9)
        }
    }

    /// At the API's own default (0.1), both slots receive the same numeric value, so the swap is
    /// invisible here -- this is exactly why the defect went unnoticed. Not a regression test by
    /// itself (passes identically whether the arguments are swapped or not); it documents the
    /// masking the issue described.
    @Test("at the default deflection (0.1) the swap is masked, by construction")
    func defaultDeflectionMasksTheSwap() throws {
        let radius = 10.0
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius))
        let edge = try #require(Shape.edgeFromCurve(circle))

        let actual = try #require(edge.edgePolyline(at: 0, deflection: 0.1, maxPoints: 4000))
        let eitherOrder = circle.drawAdaptive(
            angularDeflection: 0.1, chordalDeflection: 0.1, maxPoints: 4000)

        #expect(actual.count == eitherOrder.count)
    }
}
