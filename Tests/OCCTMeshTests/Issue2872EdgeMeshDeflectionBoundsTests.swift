import Testing
import simd

@testable import OCCTSwift

/// #2872: `OCCTShapeGetEdgeMesh` (`Sources/OCCTBridge/src/OCCTBridge_Visualization_Presentation.mm`)
/// falls back to `GCPnts_TangentialDeflection` for an edge with no triangulation polygon and no
/// `Poly_Polygon3D`, and handed the caller's deflection straight in. Same compiled-out
/// precondition as the Curve3D sites PR #2870 guarded
/// (`okf/policies/occt-validation-is-compiled-out.md`), and worse here: that loop has no
/// `maxPoints` ceiling, so an out-of-bounds deflection runs to the sampler's internal million-point
/// cap for every such edge instead of being truncated.
///
/// Two defects at the one site, and the second is why the first was weak. The constructor is
/// `(theC, theAngularDeflection /* radians */, theCurvatureDeflection /* linear */)`, and the call
/// was `disc(curve, deflection, 0.1)`: the caller's LINEAR tolerance, the same value
/// `BRepMesh_IncrementalMesh` took as its linear deflection eleven lines earlier, was landing in
/// the ANGULAR slot. That is exactly the swap #1440 fixed in `OCCTBridge_Mesh.mm`, missed here
/// because it lives in another file, and it is invisible at the API default where both slots are
/// `0.1`.
///
/// The refusal is `nil`, which is what ``Shape/edgeMesh(deflection:)`` already returns for a null
/// handle and for a shape no edge of which could be discretised.
@Suite("#2872: edge mesh deflection bounds")
struct Issue2872EdgeMeshDeflectionBoundsTests {

    /// A bare circular edge: no face, so `BRepMesh_IncrementalMesh` produces no triangulation and
    /// no `PolygonOnTriangulation`, which is the only way to reach the curve fallback this test is
    /// about. A box or a sphere never gets there.
    private let radius = 10.0

    private func circle() -> Curve3D? {
        Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius)
    }

    private func circleEdgeShape() -> Shape? {
        guard let circle = circle() else { return nil }
        return Shape.edgeFromCurve(circle)
    }

    @Test("edgeMesh meshes in range and refuses a deflection under the kernel's own bound")
    func edgeMeshBounds() throws {
        let shape = try #require(circleEdgeShape())

        let good = try #require(shape.edgeMesh(deflection: 0.1))
        #expect(good.segmentCount == 1)
        #expect(good.vertices.count >= 2)
        // A valid request on a radius-10 circle is tens of points, not thousands. The runaway this
        // guard prevents is capped at a million per edge.
        #expect(good.vertices.count < 1000)

        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be
        // written at all (swiftlang/swift#91639, see CLAUDE.md).
        for deflection in [0.0, 1e-12, 1e-9, -1.0, Double.nan] {
            #expect(
                shape.edgeMesh(deflection: deflection) == nil,
                "deflection: \(deflection) returned an edge mesh")
        }
    }

    /// The #1440 oracle, applied to this site. `Curve3D.drawAdaptive` takes explicit, correctly
    /// ordered angular and chordal parameters over the same `Geom_Curve`, so it can stand in for
    /// both the correct and the swapped call shape.
    @Test("edgeMesh's deflection lands in the linear slot, not the angular one")
    func deflectionIsLinearNotAngular() throws {
        let circle = try #require(circle())
        let shape = try #require(Shape.edgeFromCurve(circle))

        let callerDeflection = 0.005
        let hardcodedSlotValue = 0.1

        let actual = try #require(shape.edgeMesh(deflection: callerDeflection))

        let correct = circle.drawAdaptive(
            angularDeflection: hardcodedSlotValue,
            chordalDeflection: callerDeflection,
            maxPoints: 4096)
        let swapped = circle.drawAdaptive(
            angularDeflection: callerDeflection,
            chordalDeflection: hardcodedSlotValue,
            maxPoints: 4096)

        // The fixture has to separate the two call shapes, or the assertions below prove nothing.
        #expect(
            swapped.count > correct.count * 3,
            "fixture does not separate correct (\(correct.count) pts) from swapped (\(swapped.count) pts); pick another deflection or radius"
        )

        #expect(
            actual.vertices.count == correct.count,
            "edgeMesh returned \(actual.vertices.count) points, expected \(correct.count) from the correctly ordered oracle"
        )
        #expect(
            actual.vertices.count != swapped.count,
            "edgeMesh returned \(actual.vertices.count) points, matching the swapped-argument oracle (\(swapped.count))"
        )
    }

    /// At the API's own default both slots receive `0.1`, so the swap is invisible. Not a
    /// regression test by itself; it records the masking, as #1440's sibling does.
    @Test("at the default deflection the swap is masked, by construction")
    func defaultDeflectionMasksTheSwap() throws {
        let circle = try #require(circle())
        let shape = try #require(Shape.edgeFromCurve(circle))

        let actual = try #require(shape.edgeMesh(deflection: 0.1))
        let eitherOrder = circle.drawAdaptive(
            angularDeflection: 0.1, chordalDeflection: 0.1, maxPoints: 4096)

        #expect(actual.vertices.count == eitherOrder.count)
    }
}
