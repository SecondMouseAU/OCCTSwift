import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Continuity above `.c0` needs a surface to be continuous *with*. Before #430 the bridge
/// always used `BRepFill_Filling`'s face-less `Add(edge, order)` overload, which builds its
/// constraint from the *untrimmed* pcurve; the unprojectable constraint that produces then
/// tripped a null dereference inside `GeomPlate_BuildPlateSurface::Perform`, killing the
/// process with an uncatchable SIGSEGV rather than returning nil.
///
/// Every test here therefore doubles as a crash regression: *reaching* its assertions at all
/// is half the point. The other half is that tangency is really delivered, not just survived,
/// checked geometrically, since a fill that silently degrades to `.c0` also returns non-nil.
@Suite("Filling Continuity And Support Faces (#430)")
struct FillingSupportFaceTests {

    /// Truncated sphere: an open circular rim whose only adjacent face is the curved wall.
    /// The rim sits at z = 10·sin(50°) ≈ 7.66; a flat cap spans no z at all, a tangent cap
    /// leaves the rim along the sphere and so must.
    private func bowl() -> Shape? {
        Shape.sphere(
            at: SIMD3(0, 0, 0), direction: SIMD3(0, 0, 1), radius: 10,
            angle1: -.pi / 2, angle2: 50.0 * .pi / 180.0)
    }

    /// The rim is the topmost closed edge of the truncated sphere.
    private func rimEdge(of shape: Shape) -> Edge? {
        shape.edges()
            .filter { $0.isClosed3D }
            .max(by: { $0.bounds!.max.z < $1.bounds!.max.z })
    }

    private func rimWire(of shape: Shape) -> Wire? {
        guard let rim = rimEdge(of: shape) else { return nil }
        return Wire.wireFromEdges([rim])
    }

    @Test("Default parameters on a curved boundary return a surface instead of crashing")
    func defaultParametersOnCurvedBoundarySurvive() {
        guard let bowl = bowl(), let rim = rimWire(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        // FillingParameters() defaults to .g1, so this is the ordinary call that used to
        // take the whole process down. Reaching the #expect is the regression check.
        let capped = Shape.fill(boundaries: [rim])

        #expect(capped != nil)
    }

    @Test("Tangent fill against a support shape is not flat")
    func tangentFillWithSupportIsNotFlat() {
        guard let bowl = bowl(), let rim = rimWire(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        let flat = Shape.fill(
            boundaries: [rim],
            parameters: FillingParameters(continuity: .g0))
        let tangent = Shape.fill(
            boundaries: [rim], supportedBy: bowl,
            parameters: FillingParameters(continuity: .g1))

        if let flat = flat {
            // A positional fill of a planar rim is a flat disc: no z extent.
            #expect(flat.size!.z < 1e-6)
        } else {
            Issue.record("Positional fill of the rim should succeed")
        }

        if let tangent = tangent {
            #expect(tangent.isValid)
            // Tangency to the spherical wall forces the cap off the rim plane.
            #expect(tangent.size!.z > 0.5)
        } else {
            Issue.record("Tangent fill with a support shape should succeed")
        }
    }

    @Test("Explicit per-edge constraint with a support face is tangent")
    func explicitConstraintWithSupportFaceIsTangent() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        guard let wall = rim.adjacentFaces(in: bowl)?.first else {
            Issue.record("The rim should have an adjacent face to be tangent to")
            return
        }

        let capped = Shape.fill(constraints: [
            FillConstraint(edge: rim, support: wall, continuity: .g1)
        ])

        if let capped = capped {
            #expect(capped.isValid)
            #expect(capped.size!.z > 0.5)
        } else {
            Issue.record("Explicit constraint fill with a support face should succeed")
        }
    }

    @Test("Curvature continuity is accepted and differs from tangency")
    func curvatureContinuityIsAccepted() {
        guard let bowl = bowl(), let rim = rimWire(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        // Guards the continuity mapping: BRepFill_Filling forwards the GeomAbs_Shape value
        // as an integer plate order and rejects anything above 2, so curvature must map to
        // GeomAbs_C1 (ordinal 2). Mapping .g2 to GeomAbs_G2 (ordinal 3) makes this nil.
        let curvature = Shape.fill(
            boundaries: [rim], supportedBy: bowl,
            parameters: FillingParameters(continuity: .g2))
        let tangent = Shape.fill(
            boundaries: [rim], supportedBy: bowl,
            parameters: FillingParameters(continuity: .g1))

        guard let curvature = curvature, let tangent = tangent else {
            Issue.record("Both curvature and tangent fills should succeed")
            return
        }

        // Non-nil alone would also pass if .g2 silently behaved as .g1, which is the other way
        // this mapping can break. Matching the sphere's curvature as well as its tangent pushes
        // the cap measurably further than tangency alone does.
        #expect(curvature.size!.z > tangent.size!.z + 0.5)
    }

    @Test("maxDegree caps the degree of the resulting surface (#431)")
    func maxDegreeCapsResultingSurfaceDegree() {
        guard let bowl = bowl(), let rim = rimWire(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        let capped = Shape.fill(
            boundaries: [rim], supportedBy: bowl,
            parameters: FillingParameters(continuity: .g1, maxDegree: 3))

        guard let surface = capped?.faceSurfaceGeom() else {
            Issue.record("Tangent fill should produce a face with an extractable surface")
            return
        }

        // maxDegree binds to BRepOffsetAPI_MakeFilling's MaxDeg. Under the pre-#431 binding it
        // went to Degree (the energy criterion) and MaxDeg stayed at its default 8, so the
        // result overshot the requested cap, measured vDegree 6 for this same call.
        #expect(surface.uDegree <= 3)
        #expect(surface.vDegree <= 3)
    }

    @Test("A boundary edge absent from the support shape falls back rather than failing")
    func edgeNotInSupportShapeFallsBack() {
        guard let bowl = bowl(), let rim = rimWire(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        guard let unrelated = Shape.box(width: 1, height: 1, depth: 1) else {
            Issue.record("Failed to create the unrelated support shape")
            return
        }

        // The rim has no ancestor face in `unrelated`, so each edge falls back to its own
        // underlying surface, the documented degradation. It must still fill, and still be
        // tangent, rather than nil the whole operation.
        let capped = Shape.fill(
            boundaries: [rim], supportedBy: unrelated,
            parameters: FillingParameters(continuity: .g1))

        if let capped = capped {
            #expect(capped.isValid)
            #expect(capped.size!.z > 0.5)
        } else {
            Issue.record("Fill should fall back per edge, not fail outright")
        }
    }

    @Test("An internal constraint pulls the surface without bounding it")
    func internalConstraintIsNotABoundary() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        let boundaryOnly = Shape.fill(constraints: [
            FillConstraint(edge: rim, continuity: .g0)
        ])

        // A line well above the rim plane, spanning the opening. As an internal (non-bounding)
        // constraint the surface has to pass through it, so the cap can no longer be the flat
        // disc that the boundary alone produces.
        guard let interiorWire = Wire.line(from: SIMD3(-5, 0, 10), to: SIMD3(5, 0, 10)),
            let interior = interiorWire.edges().first
        else {
            Issue.record("Failed to create the interior constraint edge")
            return
        }

        let withInterior = Shape.fill(constraints: [
            FillConstraint(edge: rim, continuity: .g0),
            FillConstraint(edge: interior, continuity: .g0, isBoundary: false),
        ])

        guard let boundaryOnly = boundaryOnly, let withInterior = withInterior else {
            Issue.record("Both constraint fills should succeed")
            return
        }

        #expect(boundaryOnly.size!.z < 1e-6)  // flat disc across the rim
        #expect(withInterior.size!.z > 0.5)  // pulled up to the interior edge
    }

    @Test("Free-standing boundary has nothing to be tangent to and fails cleanly")
    func freeStandingBoundaryFailsCleanly() {
        guard let square = Wire.rectangle(width: 10, height: 10) else {
            Issue.record("Failed to create boundary wire")
            return
        }

        // No pcurve on any edge, so no continuity reference exists. This must return nil
        // rather than crash, and the positional fill of the same wire must still work.
        let tangent = Shape.fill(
            boundaries: [square],
            parameters: FillingParameters(continuity: .g1))
        let positional = Shape.fill(
            boundaries: [square],
            parameters: FillingParameters(continuity: .g0))

        #expect(tangent == nil)
        #expect(positional != nil)
    }

    @Test("Constraints fill rejects an empty constraint list")
    func emptyConstraintsReturnNil() {
        #expect(Shape.fill(constraints: []) == nil)
    }

    @Test("A nominated support face that cannot serve is a failure, not a substitution")
    func nominatedSupportFaceIsNotSilentlySubstituted() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        // Deliberately not a planar face: BRep_Tool::CurveOnSurface projects an edge onto a
        // plane on the fly when no pcurve is stored (BRep_Tool.cxx:372), so a planar face CAN
        // serve as a reference and is legitimately honoured. A sphere elsewhere in space
        // cannot, which is the case that used to be papered over.
        guard
            let unrelated = Shape.sphere(
                at: SIMD3(100, 0, 0), direction: SIMD3(0, 0, 1),
                radius: 3, angle1: -.pi / 2, angle2: .pi / 4),
            let strangerFace = unrelated.faces().first
        else {
            Issue.record("Failed to create the unrelated support face")
            return
        }

        // The rim resolves no pcurve on that face, so it cannot be the continuity reference.
        // The edge does resolve its own spherical surface, so a fallback would succeed, and
        // would silently answer with a reference the caller never asked for. Naming a face
        // means that face or nothing.
        let substituted = Shape.fill(constraints: [
            FillConstraint(edge: rim, support: strangerFace, continuity: .g1)
        ])
        #expect(substituted == nil)

        // Same edge, same continuity, no nominated face: the derivation is allowed and works.
        let derived = Shape.fill(constraints: [
            FillConstraint(edge: rim, continuity: .g1)
        ])
        if let derived = derived {
            #expect(derived.size!.z > 0.5)
        } else {
            Issue.record("Deriving a support face from the edge should still succeed")
        }
    }

    @Test("FillingSurface honours maxDegree instead of retargeting the iteration count (#431)")
    func fillingSurfaceMaxDegreeIsHonoured() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        // maxDegree used to be passed as SetResolParam's NbIter, leaving MaxDeg at its default 8
        // because SetApproxParam was never called, so the cap did nothing and the result came
        // back degree 8. Second site of #431.
        let filling = FillingSurface(maxDegree: 3)
        #expect(filling.add(edge: rim, continuity: .g1))

        guard let surface = filling.build()?.faceSurfaceGeom() else {
            Issue.record("FillingSurface should build a face with an extractable surface")
            return
        }
        #expect(surface.uDegree <= 3)
        #expect(surface.vDegree <= 3)
    }

    @Test("FillingSurface survives a curved boundary above positional continuity (#432)")
    func fillingSurfaceCurvedBoundarySurvives() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }

        // The second filling entry point reaches the same OCCT defect through its own bridge
        // implementation. Any continuity above .c0 on a curved edge used to SIGSEGV here too;
        // as with the Shape.fill tests, reaching the assertion is the regression check.
        let filling = FillingSurface()
        let added = filling.add(edge: rim, continuity: .g1)
        #expect(added)

        let face = filling.build()
        #expect(face != nil)
    }

    @Test("FillingSurface maps .g1 to tangency and .g2 to curvature, not the reverse (#433)")
    func fillingSurfaceContinuityMappingIsCorrect() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        guard let wall = rim.adjacentFaces(in: bowl)?.first else {
            Issue.record("The rim should have an adjacent face to be tangent to")
            return
        }

        // Before #433, .g1 hand-mapped to GeomAbs_C1 (curvature, ordinal 2) instead of
        // GeomAbs_G1 (tangency, ordinal 1), and .g2 mapped to GeomAbs_C2 (ordinal 4), which
        // every constraint class rejects, failing the whole build() rather than just that one
        // constraint. Mirrors Shape.fill's own "Curvature continuity is accepted and differs
        // from tangency" test above, which guards the same mapping on the other entry point.
        let tangentFilling = FillingSurface()
        #expect(tangentFilling.add(edge: rim, support: wall, continuity: .g1))
        guard let tangentFace = tangentFilling.build() else {
            Issue.record("Tangent fill via FillingSurface should succeed")
            return
        }

        let curvatureFilling = FillingSurface()
        #expect(curvatureFilling.add(edge: rim, support: wall, continuity: .g2))
        guard let curvatureFace = curvatureFilling.build() else {
            Issue.record(".g2 must be accepted, not rejected as an out-of-range plate order")
            return
        }

        #expect(tangentFace.size!.z > 0.5)
        // Non-nil alone would also pass if .g2 silently behaved as .g1. Matching curvature as
        // well as tangency pushes the cap measurably further than tangency alone.
        #expect(curvatureFace.size!.z > tangentFace.size!.z + 0.5)
    }

    @Test("add(edge:support:continuity:) rejects a support face that cannot serve (#434)")
    func fillingSurfaceNominatedSupportFaceIsNotSilentlySubstituted() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        // Same fixture as Shape.fill's "A nominated support face that cannot serve is a
        // failure, not a substitution" test: a sphere elsewhere in space resolves no pcurve
        // for the rim, so it cannot be the continuity reference.
        guard
            let unrelated = Shape.sphere(
                at: SIMD3(100, 0, 0), direction: SIMD3(0, 0, 1),
                radius: 3, angle1: -.pi / 2, angle2: .pi / 4),
            let strangerFace = unrelated.faces().first
        else {
            Issue.record("Failed to create the unrelated support face")
            return
        }

        let filling = FillingSurface()
        #expect(!filling.add(edge: rim, support: strangerFace, continuity: .g1))
    }

    @Test(
        "add(edge:support:continuity:) defaults to .g1, not .g0, so its default call validates support (#434 review)"
    )
    func fillingSurfaceAddWithSupportDefaultsToG1() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        guard let wall = rim.adjacentFaces(in: bowl)?.first else {
            Issue.record("The rim should have an adjacent face to be tangent to")
            return
        }
        guard
            let unrelated = Shape.sphere(
                at: SIMD3(100, 0, 0), direction: SIMD3(0, 0, 1),
                radius: 3, angle1: -.pi / 2, angle2: .pi / 4),
            let strangerFace = unrelated.faces().first
        else {
            Issue.record("Failed to create the unrelated support face")
            return
        }

        // At .g0, `support` is never read (occtFillingAddConstraint only looks at it above
        // GeomAbs_C0), which would make the "used or fails" doc claim false for the common
        // zero-argument call if the default were .g0. Confirms the default is .g1: a real
        // support face is accepted with no continuity argument at all...
        let filling = FillingSurface()
        #expect(filling.add(edge: rim, support: wall))
        guard let face = filling.build() else {
            Issue.record("Default-continuity fill with a real support face should succeed")
            return
        }
        #expect(face.size!.z > 0.5)  // tangent to the sphere, not a flat disc

        // ...and an unrelated support face is rejected with no continuity argument either.
        let rejecting = FillingSurface()
        #expect(!rejecting.add(edge: rim, support: strangerFace))
    }

    @Test("A refused add poisons build(), matching Shape.fill(constraints:) (#482)")
    func fillingSurfaceRefusedConstraintPoisonsBuild() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        guard
            let unrelated = Shape.sphere(
                at: SIMD3(100, 0, 0), direction: SIMD3(0, 0, 1),
                radius: 3, angle1: -.pi / 2, angle2: .pi / 4),
            let strangerFace = unrelated.faces().first
        else {
            Issue.record("Failed to create the unrelated support face")
            return
        }

        // Control: the rim alone builds. Without this the poisoned build() below would pass
        // for the wrong reason: a fill that was never going to succeed anyway.
        let control = FillingSurface()
        #expect(control.add(edge: rim, continuity: .g0))
        #expect(control.build() != nil)
        #expect(!control.hasRefusedConstraint)
        #expect(control.refusedConstraintCount == 0)

        // Same buildable constraint, plus one the builder refuses: the stranger face carries no
        // pcurve for the rim, so that constraint is never added. Before #482 build() went ahead
        // and fitted a surface to whatever did make it in: here, a face bounded by the rim with
        // no tangency at all, silently answering a question the caller did not ask. The refusal
        // is now sticky.
        let poisoned = FillingSurface()
        #expect(poisoned.add(edge: rim, continuity: .g0))
        #expect(!poisoned.add(edge: rim, support: strangerFace, continuity: .g1))
        #expect(poisoned.hasRefusedConstraint)
        #expect(poisoned.refusedConstraintCount == 1)
        #expect(poisoned.build() == nil)
        // Build() is not attempted at all, so nothing downstream reports a result either.
        #expect(!poisoned.isDone)
        #expect(poisoned.g0Error == nil)

        // The same geometry through the other entry point has always returned nil. That the two
        // now agree is the point of the change.
        #expect(
            Shape.fill(constraints: [
                FillConstraint(edge: rim, continuity: .g0, isBoundary: true),
                FillConstraint(edge: rim, support: strangerFace, continuity: .g1),
            ]) == nil)
    }

    @Test("Refusals accumulate and stay sticky across later successful adds (#482)")
    func fillingSurfaceRefusalIsStickyAndCounted() {
        guard let bowl = bowl(), let rim = rimEdge(of: bowl) else {
            Issue.record("Failed to build the truncated-sphere fixture")
            return
        }
        guard let wall = rim.adjacentFaces(in: bowl)?.first else {
            Issue.record("The rim should have an adjacent face to be tangent to")
            return
        }
        guard
            let unrelated = Shape.sphere(
                at: SIMD3(100, 0, 0), direction: SIMD3(0, 0, 1),
                radius: 3, angle1: -.pi / 2, angle2: .pi / 4),
            let strangerFace = unrelated.faces().first
        else {
            Issue.record("Failed to create the unrelated support face")
            return
        }

        let filling = FillingSurface()
        #expect(!filling.add(edge: rim, support: strangerFace, continuity: .g1))
        #expect(!filling.add(edge: rim, support: strangerFace, continuity: .g2))
        #expect(filling.refusedConstraintCount == 2)

        // A later add that succeeds (with the face that genuinely does carry the rim's pcurve,
        // so this one would build on its own) does not clear the earlier refusals.
        #expect(filling.add(edge: rim, support: wall, continuity: .g1))
        #expect(filling.refusedConstraintCount == 2)
        #expect(filling.hasRefusedConstraint)
        #expect(filling.build() == nil)
    }
}
