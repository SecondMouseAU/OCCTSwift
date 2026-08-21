import Testing
import simd
@testable import OCCTSwift

/// Issue #838: `Shape.findSurface(tolerance:)`, `Shape.findSurface(tolerance:onlyPlane:)` and
/// `Shape.findSurfaceEx(tolerance:onlyPlane:)` used to each independently construct and query their
/// own `BRepLib_FindSurface` in the bridge (`OCCTShapeFindSurface`, `OCCTFindSurface`,
/// `OCCTShapeFindSurfaceEx`). They now share one internal C++ helper (`occtRunFindSurface` /
/// `OCCTFindSurfaceResult` in `OCCTBridge_Topology.mm`). These tests lock the observable behavior of
/// that consolidation: the explicit-`tolerance:` overload shadowing status quo, the `onlyPlane`
/// forwarding, and cross-entry-point equivalence at matching parameters.
///
/// Fixtures deliberately avoid the existing box-face-wire fixture (`BRepLibFindSurfaceTests`,
/// `FindSurfaceTests`) because a plane is found there regardless of `onlyPlane`, it cannot
/// distinguish "onlyPlane forwarded correctly" from "onlyPlane silently ignored".
@Suite("Issue #838, findSurface bridge consolidation")
struct Issue838FindSurfaceConsolidationTests {

    /// A wire around a cylinder's lateral face: its edges carry an *existing* attached surface
    /// (the cylinder itself), which is not a plane. `onlyPlane: false` finds it directly (via
    /// `BRepLib_FindSurface`'s "search existing surface" phase); `onlyPlane: true` cannot (that
    /// phase discards a non-planar existing surface via a failed down-cast to `Geom_Plane`, and the
    /// least-squares plane-fit fallback it then falls through to fails too, since the wire's points
    /// span the full 10-unit height and are nowhere near coplanar).
    private func cylinderLateralWire() -> Shape? {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return nil }
        let faces = cyl.subShapes(ofType: .face)
        guard let lateralFace = faces.first(where: { $0.faceAdaptorSurfaceType == Face.SurfaceType.cylinder.rawValue }) else {
            return nil
        }
        return lateralFace.subShapes(ofType: .wire).first
    }

    /// A closed quadrilateral wire that is *almost* planar: three corners at z=0, the fourth
    /// raised by `bump`. Built from raw line segments with no attached face/pcurve at all, so
    /// `BRepLib_FindSurface` never finds an "existing surface" (regardless of `onlyPlane`) and
    /// always falls through to its least-squares plane-fit, whose residual grows with `bump`. This
    /// isolates pure tolerance forwarding from the onlyPlane-vs-existing-surface mechanism above.
    private func almostPlanarWire(bump: Double) -> Shape? {
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(10, 0, 0)
        let p2 = SIMD3<Double>(10, 10, bump)
        let p3 = SIMD3<Double>(0, 10, 0)
        let points = [p0, p1, p2, p3, p0]
        var edges: [Edge] = []
        for i in 0..<4 {
            guard let curve = Curve3D.segment(from: points[i], to: points[i + 1]),
                  let edgeShape = Shape.edgeFromCurve(curve),
                  let edge = Edge(edgeShape) else { return nil }
            edges.append(edge)
        }
        guard let wire = Wire.wireFromEdges(edges) else { return nil }
        return Shape.fromWire(wire)
    }

    // MARK: - Explicit non-default tolerance through the shadowed 1-param overload

    @Test("findSurface(tolerance:) forwards an explicit non-default tolerance, not a hardcoded one")
    func bareFindSurfaceForwardsExplicitTolerance() {
        guard let tight = almostPlanarWire(bump: 0.4), let loose = almostPlanarWire(bump: 0.4) else {
            Issue.record("fixture construction failed"); return
        }
        // Same fixture, two tolerances, through the 1-param overload (`OCCTShapeFindSurface`) that
        // `findSurface(tolerance:)` alone resolves to per Swift's overload rules.
        let notFound = tight.findSurface(tolerance: 1e-6)
        let found = loose.findSurface(tolerance: 5.0)
        #expect(notFound == nil, "a tight tolerance should reject a clearly non-planar quad")
        #expect(found != nil, "a loose tolerance should accept the same quad's best-fit plane")
    }

    // MARK: - onlyPlane forwarding (the shared-surface mechanism, not tolerance)

    @Test("findSurface(tolerance:) (1-param) behaves as onlyPlane: false, matching the explicit call")
    func bareFindSurfaceMatchesOnlyPlaneFalse() {
        guard let wire = cylinderLateralWire() else { Issue.record("fixture construction failed"); return }
        let bare = wire.findSurface(tolerance: 0.5)
        let explicitFalse = wire.findSurface(tolerance: 0.5, onlyPlane: false)
        #expect(bare != nil, "bare findSurface(tolerance:) should find the cylinder's existing surface")
        #expect(bare?.surfaceKind == .cylinder)
        #expect(explicitFalse?.surfaceKind == bare?.surfaceKind)
    }

    @Test("findSurface(tolerance:onlyPlane: true) finds nothing on a wire with only a non-planar existing surface")
    func explicitOnlyPlaneTrueFindsNothingOnNonPlanarWire() {
        guard let wire = cylinderLateralWire() else { Issue.record("fixture construction failed"); return }
        let onlyPlaneTrue = wire.findSurface(tolerance: 0.5, onlyPlane: true)
        #expect(onlyPlaneTrue == nil, "onlyPlane: true must reject the cylinder's existing surface, not silently ignore the flag")
    }

    // MARK: - Cross-entry-point equivalence at matching explicit parameters (regression lock for the refactor)

    @Test("findSurface, findSurface(onlyPlane: false) and findSurfaceEx(onlyPlane: false) agree at matching tolerance")
    func explicitOnlyPlaneFalseAgreesAcrossAllThreeEntryPoints() {
        guard let wire = cylinderLateralWire() else { Issue.record("fixture construction failed"); return }
        let tolerance = 0.5

        let viaBare = wire.findSurface(tolerance: tolerance)
        let viaTwoParam = wire.findSurface(tolerance: tolerance, onlyPlane: false)
        let viaEx = wire.findSurfaceEx(tolerance: tolerance, onlyPlane: false)

        #expect(viaBare != nil)
        #expect(viaTwoParam != nil)
        #expect(viaEx != nil)
        #expect(viaBare?.surfaceKind == .cylinder)
        #expect(viaTwoParam?.surfaceKind == .cylinder)
        #expect(viaEx?.surfaceKind == .cylinder)

        // Also lock findSurfaceTolerance/findSurfaceExisted, folded into the same shared helper.
        let tol = wire.findSurfaceTolerance(tolerance: tolerance, onlyPlane: false)
        let existed = wire.findSurfaceExisted(tolerance: tolerance, onlyPlane: false)
        #expect(tol != nil)
        #expect(existed, "the cylindrical surface was already attached to the wire's edges")
    }
}
