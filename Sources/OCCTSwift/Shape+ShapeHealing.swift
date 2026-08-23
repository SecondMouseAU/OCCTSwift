import Foundation
import OCCTBridge
import simd

extension Shape {

    // MARK: - Shape Fixing (v0.13.0)

    /// Fix shape problems with detailed control over what to fix.
    ///
    /// A second, dedicated ShapeFix_Shape entry point beside `ShapeFixer`: this one offers
    /// per-mode control (the four flags below) but no independent tolerance range, and.
    /// `ShapeFixer` offers setMinTolerance/setMaxTolerance but no mode control at all (the).
    /// two are not interchangeable (#837).
    ///
    /// - Parameters:
    ///   - tolerance: Tolerance for fixing operations
    ///   - fixSolid: Whether to fix solid orientation (`ShapeFix_Shape::FixSolidMode`)
    ///   - fixShell: Whether to fix **free** shells (shells that aren't part of a solid).
    ///     (`ShapeFix_Shape::FixFreeShellMode`)
    ///   - fixFace: Whether to fix **free** faces (faces that aren't part of a shell).
    ///     (`ShapeFix_Shape::FixFreeFaceMode`)
    ///   - fixWire: Whether to fix **free** wires (wires that aren't part of a face).
    ///     (`ShapeFix_Shape::FixFreeWireMode`)
    /// - Returns: Fixed shape, or nil on failure
    ///
    /// fixShell/fixFace/fixWire govern **free** (standalone) content specifically (a shell).
    /// not attached to a solid, a face not attached to a shell, a wire not attached to a face —.
    /// not shell/face/wire fixing in general: content that *is* attached is always fixed by
    /// `Perform()`, regardless of these three flags.
    ///
    /// ShapeFix_Shape has no plain.
    ///
    /// FixShellMode/FixFaceMode/FixWireMode in this OCCT version to offer broader control.
    ///
    /// Before #837 these three parameters were accepted but never passed to ShapeFix_Shape at.
    /// all (only fixSolid had any effect, and the other three silently behaved as if always).
    /// true regardless of what was passed, with no error and nothing in the return value to.
    /// reveal it.
    ///
    /// ## Example.
    ///
    /// ```swift.
    /// // Skip fixing free (standalone) shells/faces/wires; only fix solid orientation.
    /// let fixed = shape.fixed(tolerance: 0.001, fixShell: false, fixFace: false, fixWire: false)
    /// ```.
    public func fixed(
        tolerance: Double = 1e-6,
        fixSolid: Bool = true,
        fixShell: Bool = true,
        fixFace: Bool = true,
        fixWire: Bool = true
    ) -> Shape? {
        guard
            let result = OCCTShapeFixDetailed(
                handle, tolerance, fixSolid, fixShell, fixFace, fixWire)
        else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Shape Unification (v0.13.0)

    /// Unify faces and edges lying on the same geometry.
    ///
    /// After boolean operations, shapes often have unnecessary internal subdivisions.
    ///
    /// This method merges faces that share the same underlying surface and edges.
    /// that share the same underlying curve.
    ///
    /// The receiver is **not** modified: the merge runs on a private copy, so a caller who discards
    /// the result still holds exactly the shape they started with (#446 (the underlying OCCT).
    /// algorithm rewrites sub-shapes of its input, which used to reach the receiver).
    ///
    /// The price of that copy is **identity**: the result shares no sub-shapes with the receiver,
    /// even where nothing was merged, so `isSame(as:)`/`isPartner(with:)`/`isEqual(to:)` answer
    /// false for faces that came through untouched.
    ///
    /// Code that maps selections or attributes from.
    /// the input onto the result by sub-shape identity has to key off geometry instead.
    ///
    /// Before #446.
    /// an unmerged face came back identical (but so did the damage this method did to it).
    ///
    /// - Parameters:
    ///   - unifyEdges: Whether to merge edges on same curve (default: true)
    ///   - unifyFaces: Whether to merge faces on same surface (default: true)
    ///   - concatBSplines: Whether to concatenate adjacent B-splines (default: true (note).
    ///     ``UnifySameDomainBuilder/init(shape:unifyEdges:unifyFaces:concatBSplines:)`` defaults
    ///     this to false).
    /// - Returns: Unified shape, or nil on failure
    ///
    /// For angular/linear tolerance control, keepShape, or internal-edge handling, use.
    /// `UnifySameDomainBuilder` instead.
    ///
    /// ## Example.
    ///
    /// ```swift.
    /// // After subtracting multiple cylinders, unify to simplify topology.
    /// let result = box - cyl1 - cyl2 - cyl3.
    /// let clean = result.unified().
    /// print("Faces reduced from \(result.faceCount) to \(clean.faceCount)").
    /// ```.
    public func unified(
        unifyEdges: Bool = true,
        unifyFaces: Bool = true,
        concatBSplines: Bool = true
    ) -> Shape? {
        guard let result = OCCTShapeUnifySameDomain(handle, unifyEdges, unifyFaces, concatBSplines)
        else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Simplify a shape by unifying same-domain geometry and healing.
    ///
    /// This is a convenience method that combines `unified()` and `healed()`.
    ///
    /// As with `unified()`,.
    /// the receiver is not modified (#446).
    ///
    /// - Parameter tolerance: Tolerance for simplification operations
    /// - Returns: Simplified shape, or nil on failure
    ///
    /// ## Example.
    ///
    /// ```swift.
    /// // Clean up a complex boolean result.
    /// let simplified = result.simplified(tolerance: 0.001)
    /// ```.
    public func simplified(tolerance: Double = 1e-6) -> Shape? {
        guard let result = OCCTShapeSimplify(handle, tolerance) else {
            return nil
        }
        return Shape(handle: result)
    }

    // The enum formerly declared in Shape.swift as `GeometricContinuity` was a misnomer: it maps to
    // GeomAbs_C0...C3, so it is parametric continuity. It is now `ParametricContinuity` in
    // Continuity.swift, shared with the other APIs that take a continuity floor. See #398.

    /// Divide a shape wherever its geometry drops below the required continuity.
    ///
    /// Sets the ShapeUpgrade_ShapeDivideContinuity\'s boundary, pcurve AND surface criteria together.
    /// to continuity, plus `SetSurfaceSegmentMode(true)` (the usage OCCT's own shape-healing).
    /// guide demonstrates.
    ///
    /// Until #438 this was one of two public entry points over that same OCCT.
    /// class: ``dividedByContinuity(criterion:tolerance:)`` (now deprecated, forwarding here) set
    /// only the boundary criterion, leaving pcurve/surface pinned at the class's own C1.
    /// constructor default regardless of the requested continuity (measured).
    /// (`Scripts/repro/cluster-d-continuity`) as a flat result across every criterion on a.
    /// fixture where this method's own three-criteria behaviour varies (nil/4/4/25 faces at.
    ///
    /// C0/C1/C2/C3).
    ///
    /// ```swift.
    /// let pieces = shape.divided(at: .c2)
    /// ```.
    ///
    /// - Parameters:
    ///   - continuity: Minimum required continuity. `.cn`, `.g1` and `.g2` are accepted in
    ///     addition to `.c0`...`.c3` (#438 widened this from `ParametricContinuity`); OCCT's.
    ///     own criterion setters have no case for G1/G2 and would otherwise silently substitute.
    ///     their own C1 default, so those two are decoded ahead of the call instead.
    ///   - tolerance: Tolerance for the continuity check.
    ///
    ///   Defaults to `1e-7`.
    ///     (`Precision::Confusion()`), OCCT's own default and this method's behavior before #438
    ///     added the parameter.
    /// - Returns: Divided shape, or nil if no divisions were needed or on failure.
    public func divided(at continuity: ContinuityLevel, tolerance: Double = 1e-7) -> Shape? {
        guard let handle = OCCTShapeDivide(self.handle, continuity.rawValue, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Convert geometry to direct faces (canonical surfaces).
    ///
    /// - Returns: Shape with canonical surfaces, or nil on failure
    public func directFaces() -> Shape? {
        guard let handle = OCCTShapeDirectFaces(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Scale shape geometry by a factor.
    ///
    /// Unlike `scaled(by:)` which applies a geometric transform, this modifies the
    /// underlying surface and curve definitions.
    ///
    /// - Parameter factor: Scale factor
    /// - Returns: Scaled shape, or nil on failure
    public func scaledGeometry(factor: Double) -> Shape? {
        guard let handle = OCCTShapeScaleGeometry(self.handle, factor) else { return nil }
        return Shape(handle: handle)
    }

    /// Re-approximate surfaces, curves and pcurves as BSplines within a degree and segment budget.
    ///
    /// This does **not** recognise analytic forms (nothing here converts a BSpline back to a plane,).
    /// cylinder, cone, sphere or torus (`sweptToElementary()` and `revolutionToElementary()` are the.
    /// operations that do).
    ///
    /// It approximates each geometry as a BSpline no worse than the supplied.
    /// tolerances, capped at maxDegree and maxSegments.
    ///
    /// Continuity is fixed at C1 here; use.
    /// ``bsplineRestriction(tol3d:tol2d:maxDegree:maxSegments:continuity3d:continuity2d:degreePriority:rational:)``
    /// to choose it.
    ///
    /// Either way OCCT **reduces the continuity it delivers, silently, whenever the.
    /// requested one cannot meet the tolerance within maxDegree** (measured in #570, a face on an).
    /// offset sphere comes back at C0 no matter which of C0/C1/C2 was asked for.
    ///
    /// ```swift.
    /// let simplified = imported.bsplineRestriction(surfaceTolerance: 0.001, curveTolerance: 0.001)
    /// ```.
    ///
    /// - Parameters:
    ///   - surfaceTolerance: Tolerance for surface approximation (default: 0.01)
    ///   - curveTolerance: Tolerance for curve approximation (default: 0.01)
    ///   - maxDegree: Maximum degree for BSpline restriction (default: 9)
    ///   - maxSegments: Maximum number of segments (default: 10000)
    /// - Returns: Shape with restricted BSplines, or nil on failure
    public func bsplineRestriction(
        surfaceTolerance: Double = 0.01,
        curveTolerance: Double = 0.01,
        maxDegree: Int = 9,
        maxSegments: Int = 10000
    ) -> Shape? {
        guard
            let handle = OCCTShapeBSplineRestriction(
                self.handle, surfaceTolerance, curveTolerance,
                Int32(maxDegree), Int32(maxSegments))
        else { return nil }
        return Shape(handle: handle)
    }

    /// Convert swept surfaces to elementary (canonical) surfaces.
    ///
    /// - Returns: Shape with elementary surfaces, or nil on failure
    public func sweptToElementary() -> Shape? {
        guard let handle = OCCTShapeSweptToElementary(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert surfaces of revolution to elementary surfaces.
    ///
    /// - Returns: Shape with elementary surfaces, or nil on failure
    public func revolutionToElementary() -> Shape? {
        guard let handle = OCCTShapeRevolutionToElementary(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert all surfaces to BSpline.
    ///
    /// - Returns: Shape with BSpline surfaces, or nil on failure
    public func convertedToBSpline() -> Shape? {
        guard let handle = OCCTShapeConvertToBSpline(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Sew disconnected faces in this shape together.
    ///
    /// - Parameter tolerance: Sewing tolerance (default: 1e-6)
    /// - Returns: Sewn shape, or nil on failure
    public func sewn(tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeSewSingle(self.handle, tolerance) else { return nil }
        return Shape(handle: handle)
    }

    /// Upgrade shape: sew + make solid + heal pipeline
    ///
    /// Performs a complete upgrade of the shape by sewing disconnected faces,.
    /// attempting to create a solid from shells, and applying shape healing.
    ///
    /// The solid step builds one solid per *body-bounding* shell the sewing produced, so a.
    /// multi-body part stays a multi-body part; it comes back as a compound of solids, and.
    /// a single body as a bare solid.
    ///
    /// Body selection is the same rule as ``Shape/solid(from:)``:
    /// every shell that an **even** number of the other shells in its group enclose, where a.
    /// group is one solid's own shells, or all the shells belonging to no solid (so a free).
    /// shell that is itself an even-enclosed cavity is skipped, not turned into a body.
    ///
    /// ```swift.
    /// // A raw imported mesh holding two separate bodies.
    /// let part = imported.upgraded(tolerance: 1e-6)!
    /// print(part.solids.count)   // 2, not 1.
    /// ```.
    ///
    /// - Note: Sewing dissolves the solids in the input, so a hollow body reaches the solid
    ///   step as two free shells and comes back as one body with its **cavity filled**.
    ///   (8000 mm³ for a 7000 mm³ hollow cube). A body nested inside another body's cavity.
    ///   is still read as a body.
    ///
    ///   To heal a hollow part without losing its cavities, use.
    ///   ``Shape/fixed(tolerance:)``, which does not sew.
    ///
    /// - Note: The solid step *replaces* the sewn shape rather than merging into it, so
    ///   content sewing could not attach to a shell (a stray face, a loose edge) is not.
    ///   carried into the result.
    ///
    ///   If the input may contain such content, sew and heal it.
    ///   yourself with ``Shape/sewn(tolerance:)`` and ``Shape/fixed(tolerance:)``.
    ///
    /// - Parameter tolerance: Tolerance for sewing and healing (default: 1e-6)
    /// - Returns: Upgraded shape, or nil on failure
    public func upgraded(tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeUpgrade(self.handle, tolerance) else { return nil }
        return Shape(handle: handle)
    }
    /// Convert all curves and surfaces to NURBS representation.
    ///
    /// Useful for ensuring uniform representation before export.
    /// or for algorithms that require NURBS geometry.
    ///
    /// Wraps BRepBuilderAPI_NurbsConvert, which internally is exactly.
    /// ``nurbsConvertViaModifier()``'s BRepTools_Modifier +.
    ///
    /// BRepTools_NurbsConvertModification pair, plus one more step: `CorrectVertexTol()`.
    ///
    /// Converting an analytic curve/surface to a BSpline approximation can enlarge an edge's.
    /// tolerance to bound the approximation error, and a shared vertex's own tolerance is.
    /// expected to bound everything incident to it. (`CorrectVertexTol()` raises a vertex's).
    /// tolerance to cover any edge meeting it that the conversion touched.
    /// ``nurbsConvertViaModifier()`` skips that step, so its result can carry a vertex whose.
    /// tolerance is smaller than an edge meeting it, a real (if usually small) conversion-fidelity.
    /// gap `.isValid` will not catch.
    ///
    /// Prefer this method unless you have a specific reason to drive.
    /// the bare modifier pipeline directly (#836).
    ///
    /// - Returns: A new shape with all geometry converted to NURBS, or nil on failure
    public func convertedToNURBS() -> Shape? {
        guard let h = OCCTShapeConvertToNURBS(handle) else { return nil }
        return Shape(handle: h)
    }
    /// Sew faces using the fast sewing algorithm.
    ///
    /// Faster than `sewn(tolerance:)` for large models, but may handle
    /// fewer edge cases.
    ///
    /// - Parameter tolerance: Sewing tolerance (default: 1e-6)
    /// - Returns: The sewn shape, or nil on failure
    public func fastSewn(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeFastSewn(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
    /// Remove internal wires (holes) smaller than a minimum area.
    ///
    /// - Parameter minArea: Minimum area threshold for holes to keep
    /// - Returns: Shape with small holes removed, or nil on failure
    public func removingInternalWires(minArea: Double) -> Shape? {
        guard let h = OCCTShapeRemoveInternalWires(handle, minArea) else { return nil }
        return Shape(handle: h)
    }
    /// Remove all location transforms, baking them into the geometry.
    ///
    /// Converts a shape with nested transforms into an equivalent shape.
    /// where all geometry coordinates are in the global frame.
    ///
    /// - Returns: Shape with locations removed, or nil on failure
    public func removingLocations() -> Shape? {
        guard let h = OCCTShapeRemoveLocations(handle) else { return nil }
        return Shape(handle: h)
    }
    /// Enforce same-parameter consistency on the shape.
    ///
    /// Ensures 3D and 2D curve representations are consistent.
    ///
    /// Important.
    /// for imported geometry and after complex operations.
    ///
    /// - Parameter tolerance: Tolerance for same-parameter check
    /// - Returns: Fixed shape, or nil on failure
    public func sameParameter(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeSameParameter(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
    /// Mark smooth (G1-continuous) edges as "regular.".
    ///
    /// Downstream algorithms can skip regular edges for better performance.
    ///
    /// The angular tolerance controls what is considered "smooth.".
    ///
    /// - Parameter toleranceDegrees: Angular tolerance in degrees (default: 1e-10)
    /// - Returns: Shape with regularity encoded, or nil on failure
    public func encodingRegularity(toleranceDegrees: Double = 1e-10) -> Shape? {
        guard let h = OCCTShapeEncodeRegularity(handle, toleranceDegrees) else { return nil }
        return Shape(handle: h)
    }
    /// Recalculate and update geometric tolerances on the shape.
    ///
    /// - Parameter verifyFaces: Whether to verify and correct face tolerances
    /// - Returns: Shape with updated tolerances, or nil on failure
    public func updatingTolerances(verifyFaces: Bool = true) -> Shape? {
        guard let h = OCCTShapeUpdateTolerances(handle, verifyFaces) else { return nil }
        return Shape(handle: h)
    }
    /// Split faces into approximately the specified number of patches.
    ///
    /// Useful for mesh preparation and parametric surface subdivision.
    ///
    /// - Parameter parts: Approximate number of patches per face
    /// - Returns: Shape with divided faces, or nil on failure
    public func dividedByNumber(_ parts: Int) -> Shape? {
        guard parts > 1 else { return nil }
        guard let h = OCCTShapeDivideByNumber(handle, Int32(parts), 1) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Free Boundary Analysis (v0.39.0)

    /// Result of free boundary analysis.
    public struct FreeBoundsResult: Sendable {
        /// Compound shape containing all free boundary wires.
        public let wires: Shape
        /// Number of closed free boundary wires.
        public let closedCount: Int
        /// Number of open free boundary wires.
        public let openCount: Int
    }

    /// Analyze free boundary wires (open edges not shared by two faces).
    ///
    /// Free boundaries indicate gaps in a shell. A watertight shell has no free boundaries.
    ///
    /// - Note: Unlike `Shape.sectionWiresAtZ(_:tolerance:)`, this method is unaffected by OCCT
    ///   8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408).
    ///
    ///   This method's constructor.
    ///   does reach that same skip, in its own chainage step, so the reason is not that the call.
    ///   graph avoids it.
    ///
    ///   What keeps the result unchanged is upstream: the edges this method feeds
    ///   in come from `BRepBuilderAPI_Sewing::FreeEdge`, and in every case measured that sewing
    ///   stage never produced an `.internal`/`.external` free edge for the skip to act on.
    ///
    ///   ``freeBoundsClosedCount(tolerance:)``, ``freeBoundsClosedWires(tolerance:)`` and
    ///   ``freeBoundsOpenWires(tolerance:)`` share this reasoning unconditionally: each always
    ///   builds ShapeAnalysis_FreeBounds with the `(shape, tolerance, ...)` sewing constructor no.
    ///   matter what value is passed, so there is no other branch to consider for them.
    ///
    ///   ``freeBoundsAnalysis(tolerance:)``, `FreeBoundsProperties` and the four accessors built
    ///   on it (``closedFreeBoundInfo(tolerance:index:)``, ``openFreeBoundInfo(tolerance:index:)``,
    ///   ``closedFreeBoundWire(tolerance:index:)``, ``openFreeBoundWire(tolerance:index:)``) are
    ///   different: `ShapeAnalysis_FreeBoundsProperties::DispatchBounds()` picks the sewing
    ///   constructor only when its tolerance is greater than 0; at 0 or below it picks.
    ///   `ShapeAnalysis_FreeBounds(shape, splitClosed, splitOpen)` instead, a constructor with no.
    ///   sewing stage at all, which takes its edges from `ShapeAnalysis_Shell::CheckOrientedShells`/
    ///   `FreeEdges()` and reaches the same ConnectEdgesToWires skip by a different route.
    ///
    ///   This is.
    ///   measured directly, not assumed from the sewing case above: the `.internal` exclusion holds
    ///   on this branch too, and a FORWARD control on the same fixture confirms the two branches are.
    ///   not just trivially agreeing on everything.
    ///
    ///   The sewing branch chains a FORWARD loop entirely.
    ///   inside one face into one closed wire together with that face's outer boundary (3 closed, 0.
    ///   open); the shared-topology branch returns the same loop's four edges unchained (2 closed, 4.
    ///   open).
    ///
    ///   What is not measured, and not claimed, is *why* the INTERNAL loop is absent on the.
    ///   shared-topology branch: that constructor defaults checkinternaledges to false, so the
    ///   internal edges may never reach `FreeEdges()` as candidates at all, rather than being.
    ///   collected and then dropped by the same skip the sewing branch's chainage step hits.
    ///
    ///   Both.
    ///   would produce the same observable result, which is the only thing measured here.
    ///
    ///   See.
    ///
    ///   Issue655FreeBoundsInternalOrientationTests (OCCTShapeHealingTests) for both fixtures.
    ///
    ///   See #655.
    /// - Parameter sewingTolerance: Tolerance for grouping free edges into wires
    /// - Returns: Free bounds result, or nil if no free boundaries found
    public func freeBounds(sewingTolerance: Double = 1e-6) -> FreeBoundsResult? {
        var closedCount: Int32 = 0
        var openCount: Int32 = 0
        guard
            let h = OCCTShapeFreeBounds(
                handle, sewingTolerance,
                &closedCount, &openCount)
        else { return nil }
        return FreeBoundsResult(
            wires: Shape(handle: h),
            closedCount: Int(closedCount),
            openCount: Int(openCount))
    }

    /// Fix free boundary wires by closing gaps.
    ///
    /// - Parameters:
    ///   - sewingTolerance: Tolerance for sewing free edges
    ///   - closingTolerance: Maximum distance to close a gap
    /// - Returns: Tuple of (fixed shape, number of wires fixed), or nil on failure
    public func fixedFreeBounds(
        sewingTolerance: Double = 1e-6,
        closingTolerance: Double = 1e-4
    ) -> (shape: Shape, fixedCount: Int)? {
        var fixedCount: Int32 = 0
        guard
            let h = OCCTShapeFixFreeBounds(
                handle, sewingTolerance,
                closingTolerance, &fixedCount)
        else { return nil }
        return (shape: Shape(handle: h), fixedCount: Int(fixedCount))
    }

    // MARK: - Geometry Conversion (v0.41.0)

    /// Convert all surfaces to BSpline form.
    ///
    /// Uses ShapeCustom::ConvertToBSpline to convert extrusion, revolution,
    /// offset, and/or planar surfaces to BSpline representation.
    /// - Parameters:
    ///   - extrusion: Convert extrusion surfaces (default true)
    ///   - revolution: Convert revolution surfaces (default true)
    ///   - offset: Convert offset surfaces (default true)
    ///   - plane: Convert planar surfaces (default false)
    /// - Returns: Shape with surfaces converted, or nil on failure
    public func withSurfacesAsBSpline(
        extrusion: Bool = true, revolution: Bool = true,
        offset: Bool = true, plane: Bool = false
    ) -> Shape? {
        guard let h = OCCTShapeCustomConvertToBSpline(handle, extrusion, revolution, offset, plane)
        else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Convert surfaces to revolution form.
    ///
    /// Uses ShapeCustom::ConvertToRevolution to convert surfaces that can be
    /// represented as surfaces of revolution.
    /// - Returns: Shape with surfaces converted, or nil on failure
    public func withSurfacesAsRevolution() -> Shape? {
        guard let h = OCCTShapeCustomConvertToRevolution(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Purge problematic location datums from the shape.
    ///
    /// Removes negative-scale and non-unit-scale transforms from the shape and all.
    /// sub-shapes.
    ///
    /// Useful for cleaning imported geometry from STEP/IGES files.
    ///
    /// - Returns: Cleaned shape, or nil if purge was unnecessary or failed
    public var purgedLocations: Shape? {
        guard let ref = OCCTShapePurgeLocations(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BRepCheck_Face per-wire diagnostics (#266 follow-up)

    /// BRepCheck_Face (do this face's boundary wires intersect one another? Returns).
    /// `.intersectingWires` / `.selfIntersectingWire` on a hit, `.noError` if clean, `.checkFail`.
    /// if the shape isn't a single face. geometricControls enables the (costlier) geometric checks.
    public func checkFaceIntersectingWires(geometricControls: Bool = true) -> CheckStatus {
        CheckStatus(
            rawValue: Int32(OCCTBRepCheckFaceIntersectWires(handle, geometricControls).rawValue))
            ?? .checkFail
    }

    /// BRepCheck_Face (are the face's wires correctly nested (one outer, the rest enclosed as).
    /// holes)? Returns `.invalidImbricationOfWires` when nesting is wrong.
    public func checkFaceWireImbrication(geometricControls: Bool = true) -> CheckStatus {
        CheckStatus(
            rawValue: Int32(OCCTBRepCheckFaceClassifyWires(handle, geometricControls).rawValue))
            ?? .checkFail
    }

    /// BRepCheck_Face. (are the face's wires correctly oriented (outer CCW, holes CW)? Returns).
    /// `.badOrientationOfSubshape` / `.unorientableShape` on a problem.
    public func checkFaceWireOrientation(geometricControls: Bool = true) -> CheckStatus {
        CheckStatus(
            rawValue: Int32(OCCTBRepCheckFaceOrientationOfWires(handle, geometricControls).rawValue)
        ) ?? .checkFail
    }

    // MARK: - ShapeFix_ShapeTolerance

    /// Limit all tolerances in this shape to a given range.
    ///
    /// - Parameters:
    ///   - min: Minimum tolerance
    ///   - max: Maximum tolerance
    /// - Returns: true if any tolerance was changed
    @discardableResult
    public func limitTolerance(min: Double, max: Double) -> Bool {
        OCCTShapeFixLimitTolerance(handle, min, max)
    }

    /// Set all tolerances in this shape to a specific value.
    ///
    /// - Parameter tolerance: Tolerance value to set
    public func setTolerance(_ tolerance: Double) {
        OCCTShapeFixSetTolerance(handle, tolerance)
    }

    // MARK: - ShapeFix_SplitCommonVertex

    /// Split vertices that are shared between edges in incompatible ways.
    ///
    /// Useful for fixing topology issues where vertices are improperly shared.
    ///
    /// - Returns: Fixed shape, or nil on failure
    public func splitCommonVertices() -> Shape? {
        guard let ref = OCCTShapeFixSplitCommonVertex(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeFix_FaceConnect

    /// Connect adjacent faces in **every** shell of this shape (ShapeFix_FaceConnect).
    ///
    /// A shape with several shells (a compound of two solids, say (has each shell connected)).
    /// independently and the results reassembled: one shell in, one shell out; several in, a
    /// compound out.
    ///
    /// Before #484 only the first shell an explorer yielded was processed and the.
    /// rest were silently dropped.
    ///
    /// - Parameter tolerance: Connection tolerance.
    /// - Returns: The shape with connected faces, or nil when the input has no shell at all, or
    ///   when no shell could be connected.
    ///
    /// ## Example.
    ///
    /// ```swift.
    /// // A compound of two disjoint boxes keeps both shells (12 faces, not 6).
    /// let a = Shape.box(width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(width: 6, height: 6, depth: 6)!.translated(by: SIMD3(40, 0, 0))!
    /// let compound = Shape.compound([a, b])!.
    /// if let connected = compound.connectedFaces(tolerance: 1e-4) {
    ///     print(connected.faces().count)   // 12.
    /// }.
    /// ```.
    public func connectedFaces(tolerance: Double = 1e-4) -> Shape? {
        guard let ref = OCCTShapeFixFaceConnect(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeFix_Edge

    /// Fix same-parameter inconsistencies on all edges.
    ///
    /// - Parameter tolerance: Tolerance for fixing (0 = default)
    /// - Returns: Number of edges fixed
    @discardableResult
    public func fixEdgeSameParameter(tolerance: Double = 0) -> Int {
        Int(OCCTShapeFixEdgeSameParameter(handle, tolerance))
    }

    /// Fix vertex tolerance issues on all edges.
    ///
    /// - Returns: Number of edges fixed
    @discardableResult
    public func fixEdgeVertexTolerance() -> Int {
        Int(OCCTShapeFixEdgeVertexTolerance(handle))
    }

    // MARK: - ShapeFix_WireVertex

    /// Fix vertex issues in all wires of this shape.
    ///
    /// - Parameter precision: Precision for fixing
    /// - Returns: Number of fixes applied
    @discardableResult
    public func fixWireVertices(precision: Double = 1e-4) -> Int {
        Int(OCCTShapeFixWireVertex(handle, precision))
    }

    // MARK: - ShapeUpgrade_ShapeDivideClosed

    /// Divide closed faces in this shape.
    ///
    /// Uses ShapeUpgrade_ShapeDivideClosed to split faces that.
    /// wrap around completely (e.g., cylinder lateral face).
    ///
    /// - Parameter splitPoints: Number of split points per closed face (default: 1)
    /// - Returns: Shape with divided faces, or nil on failure
    public func dividedClosedFaces(splitPoints: Int = 1) -> Shape? {
        guard let ref = OCCTShapeUpgradeDivideClosed(handle, Int32(splitPoints)) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeFix_FixSmallSolid

    /// Remove small solids from this shape based on volume threshold.
    ///
    /// Solids with volume below the threshold are removed entirely.
    ///
    /// - Parameter volumeThreshold: Volume below which solids are removed
    /// - Returns: Shape with small solids removed, or nil on failure
    public func removeSmallSolids(volumeThreshold: Double) -> Shape? {
        guard let ref = OCCTShapeFixRemoveSmallSolids(handle, volumeThreshold) else { return nil }
        return Shape(handle: ref)
    }

    /// Merge small solids into adjacent larger solids.
    ///
    /// Small solids are merged into their neighbors rather than removed.
    ///
    /// - Parameter widthFactorThreshold: Width factor below which solids are merged
    /// - Returns: Shape with small solids merged, or nil on failure
    public func mergeSmallSolids(widthFactorThreshold: Double) -> Shape? {
        guard let ref = OCCTShapeFixMergeSmallSolids(handle, widthFactorThreshold) else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - ShapeCustom

    // Continuity for BSpline restriction is `ParametricContinuity` (Continuity.swift); the
    // nested `BSplineContinuity` copy this file used to declare is now a deprecated alias
    // of it. See #398.

    /// Simplify BSpline surfaces and curves by restricting degree and segment count.
    ///
    /// Uses ShapeCustom::BSplineRestriction to approximate geometry with simpler BSplines.
    ///
    /// ```swift.
    /// let simplified = solid.bsplineRestriction(.
    ///     tol3d: 0.001, tol2d: 0.001,
    ///     maxDegree: 4, maxSegments: 50,
    ///     continuity3d: .c2, continuity2d: .c2
    /// ).
    /// ```.
    ///
    /// ``Shape/bsplineRestrictionAdvanced(_:approxSurface:approxCurve3d:approxCurve2d:tol3d:tol2d:continuity3d:continuity2d:maxDegree:maxSegments:priorityDegree:convertRational:)``
    /// drives the same operation with per-geometry-kind switches, and takes the same continuity.
    /// vocabulary (`ShapeCustom::BSplineRestriction` is itself a ShapeCustom_BSplineRestriction).
    /// run through BRepTools_Modifier, which is what the advanced entry point builds by hand.
    ///
    /// - Parameters:
    ///   - tol3d: 3D tolerance (default: 0.01)
    ///   - tol2d: 2D tolerance (default: 0.01)
    ///   - maxDegree: Maximum BSpline degree (default: 8)
    ///   - maxSegments: Maximum number of segments (default: 100)
    ///   - continuity3d: 3D continuity requirement (default: .c1). `.c3` is rejected by the
    ///     underlying approximator and fails the whole call (nil), so `.c2` is the practical.
    ///     maximum.
    ///
    ///     This is a **ceiling, not a guarantee** (OCCT reduces the continuity it).
    ///     delivers, with no diagnostic, whenever the requested one cannot meet tol3d within.
    ///     maxDegree, and with degreePriority it degrades all the way to C0.
    ///
    ///     Measured in #570,.
    ///     a face on an offset sphere returns the identical C0 result for `.c0`, `.c1` and `.c2`.
    ///   - continuity2d: 2D continuity requirement (default: .c1), same `.c3` limit
    ///   - degreePriority: If true, prioritize degree over segments (default: true)
    ///   - rational: Allow rational BSplines (default: false)
    /// - Returns: Simplified shape, or nil on failure
    public func bsplineRestriction(
        tol3d: Double = 0.01, tol2d: Double = 0.01,
        maxDegree: Int = 8, maxSegments: Int = 100,
        continuity3d: ParametricContinuity = .c1, continuity2d: ParametricContinuity = .c1,
        degreePriority: Bool = true, rational: Bool = false
    ) -> Shape? {
        guard
            let ref = OCCTShapeCustomBSplineRestriction(
                handle, tol3d, tol2d, Int32(maxDegree), Int32(maxSegments),
                continuity3d.rawValue, continuity2d.rawValue, degreePriority, rational
            )
        else { return nil }
        return Shape(handle: ref)
    }

    /// Result of free bounds analysis.
    public struct FreeBoundsAnalysis: Sendable {
        /// Total number of free bounds.
        public let totalCount: Int
        /// Number of closed free bounds.
        public let closedCount: Int
        /// Number of open free bounds.
        public let openCount: Int
    }

    /// Analyze free bounds (boundary wires) of this shape.
    ///
    /// Free bounds are chains of edges that belong to only one face, closed into contours where.
    /// they can be.
    ///
    /// Uses ShapeAnalysis_FreeBoundsProperties to find and classify them.
    ///
    /// The shape needs to be a compound or shell of faces: the search runs over its direct
    /// children, so a lone face reports no free bounds at all.
    ///
    /// In practice the sewing pass closes.
    /// essentially every contour it finds, so ``FreeBoundsAnalysis/openCount`` is usually 0.
    ///
    /// Each of the five `…FreeBound…` methods here runs its own analysis.
    ///
    /// To read several bounds.
    /// of one shape, build a `FreeBoundsProperties` instead: it analyses once and answers every
    /// query from that one result.
    ///
    /// ```swift.
    /// let opened = Shape.compound(box.subShapes(ofType: .face).dropLast())!
    /// let analysis = opened.freeBoundsAnalysis(tolerance: 1e-3)
    /// print(analysis.closedCount)  // 1, the contour around the missing face.
    ///
    /// if let bound = opened.closedFreeBoundInfo(tolerance: 1e-3, index: 0) {
    ///     print(bound.area, bound.perimeter).
    /// }.
    /// ```.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408),
    ///   at any tolerance, including the `tolerance <= 0` input documented below that routes to a.
    ///   different constructor with no sewing stage at all; see ``freeBounds(sewingTolerance:)`` for
    ///   why, on both branches.
    ///
    ///   See #655.
    /// - Parameter tolerance: Sewing tolerance used to chain free edges into contours. 0 or below
    ///   selects a different OCCT algorithm, taking free edges from the shape's already-shared.
    ///   topology instead of from a sewing pass.
    /// - Returns: Analysis summary with bound counts
    public func freeBoundsAnalysis(tolerance: Double) -> FreeBoundsAnalysis {
        guard let props = FreeBoundsProperties(shape: self, tolerance: tolerance) else {
            return FreeBoundsAnalysis(totalCount: 0, closedCount: 0, openCount: 0)
        }
        return FreeBoundsAnalysis(
            totalCount: props.totalCount,
            closedCount: props.closedCount,
            openCount: props.openCount
        )
    }

    /// Get properties of a closed free bound.
    ///
    /// See ``freeBoundsAnalysis(tolerance:)`` for what the tolerance selects, and
    /// `FreeBoundsProperties` for reading several bounds without re-analysing each time.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408),
    ///   at any tolerance; see ``freeBounds(sewingTolerance:)`` for why, on both branches.
    ///
    ///   See #655.
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the closed free bound
    /// - Returns: Properties of the bound, or nil if index is out of range
    public func closedFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo? {
        FreeBoundsProperties(shape: self, tolerance: tolerance)?.info(.closed, at: index)
    }

    /// Get properties of an open free bound.
    ///
    /// See ``freeBoundsAnalysis(tolerance:)`` for what the tolerance selects, and
    /// `FreeBoundsProperties` for reading several bounds without re-analysing each time.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408),
    ///   at any tolerance; see ``freeBounds(sewingTolerance:)`` for why, on both branches.
    ///
    ///   See #655.
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the open free bound
    /// - Returns: Properties of the bound, or nil if index is out of range
    public func openFreeBoundInfo(tolerance: Double, index: Int) -> FreeBoundInfo? {
        FreeBoundsProperties(shape: self, tolerance: tolerance)?.info(.open, at: index)
    }

    /// Get the wire shape of a closed free bound.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408),
    ///   at any tolerance; see ``freeBounds(sewingTolerance:)`` for why, on both branches.
    ///
    ///   See #655.
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the closed free bound
    /// - Returns: Wire as a Shape, or nil if index is out of range
    public func closedFreeBoundWire(tolerance: Double, index: Int) -> Shape? {
        FreeBoundsProperties(shape: self, tolerance: tolerance)?.wire(.closed, at: index)
    }

    /// Get the wire shape of an open free bound.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408),
    ///   at any tolerance; see ``freeBounds(sewingTolerance:)`` for why, on both branches.
    ///
    ///   See #655.
    /// - Parameters:
    ///   - tolerance: Same tolerance used for analysis
    ///   - index: 0-based index of the open free bound
    /// - Returns: Wire as a Shape, or nil if index is out of range
    public func openFreeBoundWire(tolerance: Double, index: Int) -> Shape? {
        FreeBoundsProperties(shape: self, tolerance: tolerance)?.wire(.open, at: index)
    }

    /// Result of wire vertex analysis.
    public struct WireVertexAnalysis {
        /// Number of edges in the wire.
        public let edgeCount: Int
        /// Whether the analysis completed successfully.
        public let isDone: Bool
    }

    /// Vertex status codes from wire vertex analysis.
    public enum WireVertexStatus: Int32 {
        case sameVertex = 0
        case sameCoords = 1
        case close = 2
        case end = 3
        case start = 4
        case intersection = 5
        case disjoined = -1
        case unknown = -2
    }

    /// Analyze wire vertex connections for gaps, overlaps, and intersections.
    ///
    /// - Parameter precision: Tolerance for vertex analysis
    /// - Returns: Analysis result with edge count
    public func wireVertexAnalysis(precision: Double = 0.01) -> WireVertexAnalysis {
        let result = OCCTShapeWireVertexAnalysis(handle, precision)
        return WireVertexAnalysis(edgeCount: Int(result.nbEdges), isDone: result.isDone)
    }

    /// Get the status of a specific vertex in a wire.
    ///
    /// - Parameters:
    ///   - precision: Tolerance for vertex analysis
    ///   - index: 0-based vertex index
    /// - Returns: Vertex status
    public func wireVertexStatus(precision: Double = 0.01, index: Int) -> WireVertexStatus {
        let code = OCCTShapeWireVertexStatus(handle, precision, Int32(index))
        return WireVertexStatus(rawValue: code) ?? .unknown
    }

    /// Result of fitting a plane to a set of points.
    public struct NearestPlane {
        /// Normal direction of the fitted plane.
        public let normal: SIMD3<Double>
        /// A point on the fitted plane.
        public let origin: SIMD3<Double>
        /// Maximum distance from any input point to the fitted plane.
        public let maxDeviation: Double
    }

    /// Fit the nearest plane to a set of 3D points.
    ///
    /// Uses least-squares fitting to find the plane that best fits the points.
    ///
    /// - Parameter points: Array of 3D points (minimum 3)
    /// - Returns: Fitted plane with deviation, or nil if fitting fails
    public static func nearestPlane(to points: [SIMD3<Double>]) -> NearestPlane? {
        guard points.count >= 3 else { return nil }
        var flatPoints = [Double]()
        flatPoints.reserveCapacity(points.count * 3)
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }
        let result = OCCTShapeNearestPlane(flatPoints, Int32(points.count))
        guard result.success else { return nil }
        return NearestPlane(
            normal: SIMD3(result.normalX, result.normalY, result.normalZ),
            origin: SIMD3(result.originX, result.originY, result.originZ),
            maxDeviation: result.maxDeviation)
    }

    // MARK: - ShapeUpgrade_ShellSewing

    /// Sew disconnected shells in this shape.
    ///
    /// Connects shells that share edges within the given tolerance.
    ///
    /// - Parameter tolerance: Sewing tolerance (default 1e-6)
    /// - Returns: Sewn shape, or nil on failure
    public func shellSewing(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeUpgradeShellSewing(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepTools_Modifier + NurbsConvertModification

    /// Convert shape to NURBS via BRepTools_Modifier directly, skipping.
    /// ``convertedToNURBS()``'s vertex-tolerance correction pass.
    ///
    /// This drives the exact same BRepTools_Modifier + BRepTools_NurbsConvertModification.
    /// pair ``convertedToNURBS()`` (BRepBuilderAPI_NurbsConvert) uses internally (the two are).
    /// not independent conversion mechanisms; this one is that method's own implementation minus.
    /// its final `CorrectVertexTol()` step.
    ///
    /// That step matters: converting an analytic
    /// curve/surface to a BSpline approximation can enlarge an edge's tolerance to bound the.
    /// approximation error, and without the correction a shared vertex's recorded tolerance can.
    /// end up smaller than an edge meeting it (a real, silent conversion-fidelity gap `.isValid`).
    /// will not catch (#836).
    ///
    /// Prefer ``convertedToNURBS()`` for ordinary NURBS conversion.
    ///
    /// Use this method only when you.
    /// need the bare BRepTools_Modifier pipeline directly (e.g. composing the conversion with).
    /// other BRepTools_Modification passes in one BRepTools_Modifier pass (and will apply).
    /// your own vertex-tolerance correction afterward if the result's vertices need to stay.
    /// consistent with their edges' tolerances.
    public func nurbsConvertViaModifier() -> Shape? {
        guard let h = OCCTBRepToolsModifierNurbsConvert(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: ShapeCustom_DirectModification

    /// Orient face normals outward using ShapeCustom_DirectModification.
    public func directModification() -> Shape? {
        guard let h = OCCTShapeCustomDirectModification(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: ShapeCustom_TrsfModification

    /// Apply a uniform scale with proper tolerance handling via ShapeCustom_TrsfModification.
    public func trsfModificationScale(_ scaleFactor: Double) -> Shape? {
        guard let h = OCCTShapeCustomTrsfModificationScale(handle, scaleFactor) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - ShapeAnalysis_TransferParametersProj

    /// Transfer a parameter from edge to face coordinate system via projection.
    public func transferParameterToFace(_ param: Double, face: Shape) -> Double {
        OCCTShapeAnalysisTransferParam(handle, face.handle, param, true)
    }

    /// Transfer a parameter from face to edge coordinate system via projection.
    public func transferParameterFromFace(_ param: Double, face: Shape) -> Double {
        OCCTShapeAnalysisTransferParam(handle, face.handle, param, false)
    }

    // MARK: - ShapeBuild_Edge

    /// Copy an edge, optionally sharing PCurves.
    ///
    /// - Parameter sharePCurves: If true, share PCurves with original (default: true)
    /// - Returns: Copied edge as shape, or nil on failure
    public func copyEdge(sharePCurves: Bool = true) -> Shape? {
        guard let ref = OCCTShapeBuildEdgeCopy(handle, sharePCurves) else { return nil }
        return Shape(handle: ref)
    }

    /// Copy an edge replacing its start and/or end vertices.
    ///
    /// - Parameters:
    ///   - startVertex: New start vertex (pass nil to keep original)
    ///   - endVertex: New end vertex (pass nil to keep original)
    /// - Returns: Edge with replaced vertices, or nil on failure
    public func copyEdgeReplacingVertices(startVertex: Shape?, endVertex: Shape?) -> Shape? {
        guard
            let ref = OCCTShapeBuildEdgeCopyReplaceVertices(
                handle, startVertex?.handle, endVertex?.handle)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Set the 3D parameter range on this edge shape.
    public func setEdgeRange3d(first: Double, last: Double) {
        OCCTShapeBuildEdgeSetRange3d(handle, first, last)
    }

    /// Rebuild the 3D curve of an edge from its PCurves.
    /// - Returns: true if curve was rebuilt successfully
    @discardableResult
    public func buildEdgeCurve3d() -> Bool {
        OCCTShapeBuildEdgeBuildCurve3d(handle)
    }

    /// Remove the 3D curve from this edge.
    public func removeEdgeCurve3d() {
        OCCTShapeBuildEdgeRemoveCurve3d(handle)
    }

    /// Copy parameter ranges from another edge to this edge.
    public func copyEdgeRanges(from source: Shape) {
        OCCTShapeBuildEdgeCopyRanges(handle, source.handle)
    }

    /// Copy PCurves from another edge to this edge.
    public func copyEdgePCurves(from source: Shape) {
        OCCTShapeBuildEdgeCopyPCurves(handle, source.handle)
    }

    /// Remove the PCurve from this edge for a given face.
    public func removeEdgePCurve(onFace face: Shape) {
        OCCTShapeBuildEdgeRemovePCurve(handle, face.handle)
    }

    /// Reassign a PCurve from one face to another.
    /// - Returns: true if reassignment succeeded
    @discardableResult
    public func reassignEdgePCurve(from oldFace: Shape, to newFace: Shape) -> Bool {
        OCCTShapeBuildEdgeReassignPCurve(handle, oldFace.handle, newFace.handle)
    }

    // MARK: - ShapeBuild_Vertex

    /// Combine two vertex shapes into one at their average position.
    ///
    /// - Parameters:
    ///   - other: Other vertex shape to combine with
    ///   - tolFactor: Tolerance factor (default: 1.0001)
    /// - Returns: Combined vertex as shape, or nil on failure
    public func combineVertex(with other: Shape, tolFactor: Double = 1.0001) -> Shape? {
        guard let ref = OCCTShapeBuildVertexCombine(handle, other.handle, tolFactor) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a vertex by combining two 3D points.
    ///
    /// - Parameters:
    ///   - point1: First point
    ///   - tol1: Tolerance of first point
    ///   - point2: Second point
    ///   - tol2: Tolerance of second point
    ///   - tolFactor: Tolerance factor (default: 1.0001)
    /// - Returns: Combined vertex as shape, or nil on failure
    public static func combineVertices(
        point1: SIMD3<Double>, tol1: Double,
        point2: SIMD3<Double>, tol2: Double,
        tolFactor: Double = 1.0001
    ) -> Shape? {
        guard
            let ref = OCCTShapeBuildVertexCombineFromPoints(
                point1.x, point1.y, point1.z, tol1,
                point2.x, point2.y, point2.z, tol2,
                tolFactor)
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeExtend_Explorer

    /// Shape type for filtering compounds.
    ///
    /// A typealias for the canonical `ShapeType` (#844) (this used to be an independent local).
    /// mirror of the same TopAbs_ShapeEnum ordinals, with its own, differently-cased compsolid.
    /// case (ShapeType spells it compSolid).
    ///
    /// ShapeExtend_Explorer uses the identical ordinal.
    /// convention every other sub-shape-type API in this package does, so there was no reason for.
    /// a second declaration once the casing was reconciled.
    public typealias ShapeFilterType = ShapeType

    /// Filter this compound shape, extracting only sub-shapes of the specified type.
    ///
    /// - Parameters:
    ///   - type: Shape type to extract
    ///   - explore: If true, explore sub-compounds recursively
    /// - Returns: Compound containing only shapes of the specified type, or nil on failure
    public func sortedCompound(type: ShapeFilterType, explore: Bool = true) -> Shape? {
        guard let ref = OCCTShapeExtendSortedCompound(handle, Int32(type.rawValue), explore) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get the predominant shape type in this compound.
    ///
    /// - Parameter lookInsideCompounds: If true, look inside sub-compounds
    /// - Returns: The predominant shape type, or ``ShapeType/unknown`` if the underlying
    ///   ShapeExtend_Explorer walk throws (fixed in PR #870's aggregate review (this used to).
    ///   decode as ``ShapeType/vertex``, a real, legitimate case, indistinguishable from an actual.
    ///   vertex-dominated shape).
    public func predominantShapeType(lookInsideCompounds: Bool = true) -> ShapeFilterType {
        let raw = OCCTShapeExtendShapeType(handle, lookInsideCompounds)
        return ShapeFilterType(rawValue: Int(raw)) ?? .compound
    }

    // MARK: - ShapeUpgrade_FaceDivide

    /// Divide a face using surface segmentation.
    ///
    /// Uses ShapeUpgrade_FaceDivide to split a face based on surface properties.
    ///
    /// - Returns: Divided shape, or nil on failure
    public func divideFace() -> Shape? {
        guard let ref = OCCTShapeUpgradeFaceDivide(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_WireDivide

    /// Divide a wire on a face.
    ///
    /// Uses ShapeUpgrade_WireDivide to split wire edges.
    ///
    /// - Parameter face: Face the wire lies on
    /// - Returns: Divided wire as shape, or nil on failure
    public func divideWire(onFace face: Shape) -> Shape? {
        guard let ref = OCCTShapeUpgradeWireDivideOnFace(handle, face.handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_EdgeDivide

    /// Result of edge divide analysis.
    public struct EdgeDivideResult: Sendable {
        /// Whether the edge has a 2D curve on the face.
        public let hasCurve2d: Bool
        /// Whether the edge has a 3D curve.
        public let hasCurve3d: Bool
    }

    /// Analyze an edge for potential division on a face.
    ///
    /// - Parameter face: Face context for the edge
    /// - Returns: Analysis result, or nil on failure
    public func analyzeEdgeDivide(onFace face: Shape) -> EdgeDivideResult? {
        var hasCurve2d = false
        var hasCurve3d = false
        let ok = OCCTShapeUpgradeEdgeDivideCompute(handle, face.handle, &hasCurve2d, &hasCurve3d)
        guard ok else { return nil }
        return EdgeDivideResult(hasCurve2d: hasCurve2d, hasCurve3d: hasCurve3d)
    }

    // MARK: - ShapeUpgrade_ClosedEdgeDivide

    /// Check if a closed (seam) edge can be divided on a face.
    ///
    /// - Parameter face: Face context
    /// - Returns: true if the edge is closed and can be divided
    public func canDivideClosedEdge(onFace face: Shape) -> Bool {
        OCCTShapeUpgradeClosedEdgeDivideCompute(handle, face.handle)
    }

    // MARK: - ShapeUpgrade_FixSmallCurves

    /// Fix small curves in this shape.
    ///
    /// - Parameter tolerance: Tolerance for small curve detection (default: 1e-6)
    /// - Returns: Fixed shape, or nil on failure
    public func fixSmallCurves(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeUpgradeFixSmallCurves(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_FixSmallBezierCurves

    /// Fix small Bezier curves in this shape.
    ///
    /// - Parameter tolerance: Tolerance for small curve detection (default: 1e-6)
    /// - Returns: Fixed shape, or nil on failure
    public func fixSmallBezierCurves(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeUpgradeFixSmallBezierCurves(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_ConvertCurve3dToBezier

    /// Convert 3D curves in this shape to Bezier representation.
    ///
    /// - Parameters:
    ///   - lineMode: Convert lines to Bezier (default: true)
    ///   - circleMode: Convert circles to Bezier (default: true)
    ///   - conicMode: Convert conics to Bezier (default: true)
    /// - Returns: Shape with Bezier curves, or nil on failure
    public func convertCurves3dToBezier(
        lineMode: Bool = true, circleMode: Bool = true,
        conicMode: Bool = true
    ) -> Shape? {
        guard
            let ref = OCCTShapeUpgradeConvertCurves3dToBezier(
                handle, lineMode, circleMode, conicMode)
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - ShapeUpgrade_ConvertSurfaceToBezierBasis

    /// Convert surfaces in this shape to Bezier patches.
    ///
    /// - Parameters:
    ///   - planeMode: Convert planes (default: true)
    ///   - revolutionMode: Convert surfaces of revolution (default: true)
    ///   - extrusionMode: Convert extrusion surfaces (default: true)
    ///   - bsplineMode: Convert BSpline surfaces (default: true)
    /// - Returns: Shape with Bezier surfaces, or nil on failure
    public func convertSurfacesToBezier(
        planeMode: Bool = true, revolutionMode: Bool = true,
        extrusionMode: Bool = true, bsplineMode: Bool = true
    ) -> Shape? {
        guard
            let ref = OCCTShapeUpgradeConvertSurfaceToBezier(
                handle, planeMode, revolutionMode,
                extrusionMode, bsplineMode)
        else {
            return nil
        }
        return Shape(handle: ref)
    }
    /// Create a triangulated face from 3D points.
    public static func triangulationFromPoints(_ points: [(Double, Double, Double)]) -> Shape? {
        var coords: [Double] = []
        for p in points {
            coords.append(p.0)
            coords.append(p.1)
            coords.append(p.2)
        }
        guard let ref = OCCTShapeConstructTriangulationFromPoints(coords, Int32(points.count))
        else { return nil }
        return Shape(handle: ref)
    }

    /// Create a triangulated face from a wire.
    public static func triangulationFromWire(_ wire: Wire) -> Shape? {
        guard let ref = OCCTShapeConstructTriangulationFromWire(wire.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Restrict BSpline degree and segments with full control (advanced version).
    ///
    /// Same operation as.
    /// ``Shape/bsplineRestriction(tol3d:tol2d:maxDegree:maxSegments:continuity3d:continuity2d:degreePriority:rational:)``
    /// — both drive a ShapeCustom_BSplineRestriction through BRepTools_Modifier (with).
    /// switches for which geometry kinds to approximate.
    ///
    /// ```swift.
    /// // Surfaces only, leave the curves alone.
    /// let restricted = Shape.bsplineRestrictionAdvanced(.
    ///     solid,.
    ///     approxSurface: true, approxCurve3d: false, approxCurve2d: false,
    ///     continuity3d: .c1, continuity2d: .c1
    /// ).
    /// ```.
    ///
    /// - Parameters:
    ///   - continuity3d: 3D continuity requirement (default: `.c1`). `.c3` is rejected by the
    ///     underlying approximator and fails the whole call (nil), so `.c2` is the practical.
    ///     maximum (the same limit the non-advanced entry point has).
    ///
    ///     Also the same ceiling-not-a-.
    ///     guarantee: OCCT silently reduces the delivered continuity when the requested one cannot
    ///     meet tol3d within maxDegree (#570).
    ///   - continuity2d: 2D continuity requirement (default: `.c1`), same `.c3` limit
    /// - Returns: Restricted shape, or nil on failure
    public static func bsplineRestrictionAdvanced(
        _ shape: Shape,
        approxSurface: Bool = true,
        approxCurve3d: Bool = true,
        approxCurve2d: Bool = true,
        tol3d: Double = 0.01,
        tol2d: Double = 0.01,
        continuity3d: ParametricContinuity = .c1,
        continuity2d: ParametricContinuity = .c1,
        maxDegree: Int = 5,
        maxSegments: Int = 20,
        priorityDegree: Bool = true,
        convertRational: Bool = false
    ) -> Shape? {
        guard
            let ref = OCCTShapeBSplineRestrictionAdvanced(
                shape.handle,
                approxSurface, approxCurve3d, approxCurve2d,
                tol3d, tol2d,
                continuity3d.rawValue, continuity2d.rawValue,
                Int32(maxDegree), Int32(maxSegments),
                priorityDegree, convertRational)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Convert surfaces to BSpline with per-type control.
    public static func convertToBSplineAdvanced(
        _ shape: Shape,
        extrusionMode: Bool = true,
        revolutionMode: Bool = true,
        offsetMode: Bool = true,
        planeMode: Bool = false
    ) -> Shape? {
        guard
            let ref = OCCTShapeConvertToBSplineAdvanced(
                shape.handle,
                extrusionMode, revolutionMode,
                offsetMode, planeMode)
        else { return nil }
        return Shape(handle: ref)
    }
    /// Compose shell: split a face into sub-faces using composite surface grid.
    public func composeShell(precision: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFixComposeShell(handle, precision) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Fix a solid shape (topology and orientation), using ShapeFix_Solid.
    ///
    /// Every solid in the receiver is healed, not just the first: a single-body input
    /// comes back as a solid, a multi-body one as a compound of one result per input body,.
    /// in exploration order. A compound result is not new to this call (ShapeFix_Solid).
    /// already returns one when a single solid's shells resolve into several bodies.
    ///
    /// Only the receiver's *solids* are visited.
    ///
    /// Loose shells, faces or wires sitting.
    /// alongside them in a compound are not carried over, and an input holding no solid at.
    /// all returns nil.
    ///
    /// To heal a whole shape of mixed content instead, use.
    /// ``Shape/fixed(tolerance:fixSolid:fixShell:fixFace:fixWire:)``, which wraps
    /// ShapeFix_Shape and preserves everything it is given.
    ///
    /// - Warning: A result body is usually a healed solid, but **not always**, and no body
    ///   is ever dropped to make that true.
    ///
    ///   ShapeFix_Solid hands back a **shell** when it.
    ///   cannot close one into a solid, and a solid it fails to heal outright is returned.
    ///   **unhealed** rather than discarded.
    ///
    ///   So `result.solids.count` can be lower than the.
    ///   number of input bodies even though nothing was lost.
    ///
    ///   To spot an unclosed body, walk the result's **direct children** (not).
    ///   ``Shape/subShapes(ofType:)``, which maps at every depth and so reports one shell
    ///   for every *healthy* solid too (a compound of two healed solids has two shells, and.
    ///   a single healed solid has one):
    ///
    ///   ```swift.
    ///   let healed = part.fixSolid()!.
    ///   let bodies = (0..<healed.nbChildren).compactMap { healed.child(at: $0) }
    ///   let unclosed = bodies.filter { $0.shapeType == .shell }.
    ///   ```.
    ///
    ///   When a single body came back, the result is that body rather than a compound, so.
    ///   `healed.shapeType == .shell` answers it directly, or check ``Shape/isValidSolid``.
    ///   directly, which does the same `shapeType == .solid` test itself before its own.
    ///
    ///   BRepCheck_Analyzer pass, so it reads false on a demoted shell where plain.
    ///   ``Shape/isValid`` reads true (#702: a demoted shell has no closure requirement of its
    ///   own, so it is genuinely, unmisleadingly valid, just not a solid any more). A body that.
    ///   came back *unhealed* is still a solid: use ``Shape/isValid`` for that, or
    ///   ``Shape/isValidSolid`` for both checks in one.
    ///
    /// ```swift.
    /// let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
    /// let part = Shape.compound([a, b])!.
    ///
    /// let healed = part.fixSolid()!.
    /// print(healed.solids.count)   // 2 (both bodies, not just the first).
    /// print(healed.volume!)        // 2000.0.
    /// ```.
    ///
    /// - Returns: The repaired body, or a compound of one result per input body for
    ///   multi-body input, or nil if the receiver holds no solid.
    public func fixSolid() -> Shape? {
        guard let ref = OCCTShapeFixSolid(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a solid from a shell shape using ShapeFix_Solid, orienting it to enclose.
    /// a finite volume.
    ///
    /// One solid is built per *body-bounding* shell, not just the first shell found: every
    /// shell that an **even** number of the other shells in its group enclose, where a group.
    /// is one solid's own shells, or all the shells belonging to no solid (the usual shape.
    /// of sewing output). A single body comes back as a solid, several as a compound in.
    /// exploration order.
    ///
    /// *Cavity* shells are deliberately skipped: a hole is not a body, and building it as a
    /// positive solid would yield a compound whose volume double-counts the part.
    ///
    /// So a.
    /// hollow solid produces one solid bounded by its outer shell, with the cavity filled,.
    /// and so does that same body after sewing has left its two shells free. A body nested.
    /// inside another body's cavity is enclosed twice, so it is still read as a body.
    ///
    /// To.
    /// rebuild a solid that keeps its cavities, use ``Shape/solidFromShells(_:)`` with the
    /// outer shell first.
    ///
    /// ```swift.
    /// let quilt = Shape.compound([shellA, shellB])!   // e.g. two sewn bodies.
    /// let solids = quilt.solidFromShellFixed()!.
    /// print(solids.solids.count)   // 2 (one solid per shell).
    /// ```.
    ///
    /// - Important: An **open** shell is not rejected. `ShapeFix_Solid::SolidFromShell`
    ///   builds its solid before classifying anything and never returns a null one, so a.
    ///   shell with gaps comes back as a solid that is not closed rather than as nil.
    ///
    ///   Check ``Shape/isValid`` or sew first if the input may be open.
    ///
    /// - Returns: A solid, a compound of solids for multi-body input, or nil only if the
    ///   receiver holds no shell at all.
    public func solidFromShellFixed() -> Shape? {
        guard let ref = OCCTShapeSolidFromShell(handle) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Connect edges in a shape by extending/trimming to match.
    public func fixEdgeConnect() -> Shape? {
        guard let ref = OCCTShapeFixEdgeConnect(handle) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Result of shell analysis.
    public struct ShellAnalysisResult: Sendable {
        public let hasOrientationProblems: Bool
        public let hasFreeEdges: Bool
        public let hasBadEdges: Bool
        public let hasConnectedEdges: Bool
        public let freeEdgeCount: Int
    }

    /// Analyze shell orientation and edge connectivity.
    public func analyzeShell() -> ShellAnalysisResult {
        let r = OCCTShapeAnalyzeShell(handle)
        return ShellAnalysisResult(
            hasOrientationProblems: r.hasOrientationProblems,
            hasFreeEdges: r.hasFreeEdges,
            hasBadEdges: r.hasBadEdges,
            hasConnectedEdges: r.hasConnectedEdges,
            freeEdgeCount: Int(r.freeEdgeCount)
        )
    }
}

extension Shape {

    /// Project edge endpoints onto face pcurve.
    /// - Parameters:
    ///   - faceIndex: Index of the face (0-based)
    ///   - edgeIndex: Index of the edge within the face (0-based)
    ///   - precision: Projection precision
    /// - Returns: (firstParam, lastParam) or nil if projection fails
    public func edgeProjAux(faceIndex: Int, edgeIndex: Int, precision: Double = 1e-6) -> (
        first: Double, last: Double
    )? {
        var first = 0.0
        var last = 0.0
        guard
            OCCTShapeFixEdgeProjAux(
                handle, Int32(faceIndex), Int32(edgeIndex), precision, &first, &last)
        else {
            return nil
        }
        return (first, last)
    }
}

extension Shape {

    /// Fix intersecting wires on a face of this shape.
    /// - Parameters:
    ///   - faceIndex: Index of the face (0-based)
    ///   - precision: Fix precision
    /// - Returns: true if fixes were applied
    @discardableResult
    public func fixIntersectingWires(faceIndex: Int, precision: Double = 1e-6) -> Bool {
        OCCTShapeFixIntersectingWires(handle, Int32(faceIndex), precision)
    }
}

extension Shape {

    /// Fix only wire gaps in the shape (no small-edge removal).
    /// - Parameter tolerance: Precision for gap detection.
    /// - Returns: Fixed shape, or nil on failure.
    public func fixWireGaps(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTShapeFixWireGaps(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Fix only small edges in the shape (no gap repair).
    /// - Parameters:
    ///   - tolerance: Precision for small-edge detection.
    ///   - dropSmall: If true, remove small edges; if false, merge them with neighbours.
    ///   - limitAngle: Maximum tangent angle for merging (radians).
    ///
    ///   Pass -1 for no limit.
    /// - Returns: Fixed shape, or nil on failure.
    public func fixSmallEdges(
        tolerance: Double = 1e-7,
        dropSmall: Bool = false,
        limitAngle: Double = -1
    ) -> Shape? {
        guard let ref = OCCTShapeFixSmallEdges(handle, tolerance, dropSmall, limitAngle) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

extension Shape {

    /// Count the number of closed free-boundary wires.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408);
    ///   see ``freeBounds(sewingTolerance:)`` for why.
    ///
    ///   See #655.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Number of closed free-boundary wires.
    public func freeBoundsClosedCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTShapeFreeBoundsClosedCount(handle, tolerance))
    }

    /// Get the compound of closed free-boundary wires.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408);
    ///   see ``freeBounds(sewingTolerance:)`` for why.
    ///
    ///   See #655.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Compound shape of closed wires, or nil if none.
    public func freeBoundsClosedWires(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFreeBoundsClosed(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the compound of open free-boundary wires.
    ///
    /// - Note: Unaffected by OCCT 8.0.1's ConnectEdgesToWires INTERNAL/EXTERNAL skip (OCCT#1408);
    ///   see ``freeBounds(sewingTolerance:)`` for why.
    ///
    ///   See #655.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Compound shape of open wires, or nil if none.
    public func freeBoundsOpenWires(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFreeBoundsOpen(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Tolerance mode for shape tolerance queries.
    public enum ToleranceMode: Int32, Sendable {
        case average = 0
        case maximum = 1
        case minimum = -1
    }

    /// Get the tolerance value of the shape's sub-shapes.
    /// subShapeType: 8=all(SHAPE), 7=VERTEX, 6=EDGE, 4=FACE, 3=SHELL
    public func toleranceValue(mode: ToleranceMode, subShapeType: Int32 = 8) -> Double {
        OCCTShapeToleranceValue(handle, mode.rawValue, subShapeType)
    }

    /// Count sub-shapes with tolerance over a given value.
    /// subShapeType: 8=all(SHAPE), 7=VERTEX, 6=EDGE, 4=FACE
    public func toleranceOverCount(value: Double, subShapeType: Int32 = 8) -> Int {
        Int(OCCTShapeToleranceOverCount(handle, value, subShapeType))
    }

    /// Count sub-shapes with tolerance in a given range.
    /// subShapeType: 8=all(SHAPE), 7=VERTEX, 6=EDGE, 4=FACE
    public func toleranceInRangeCount(min: Double, max: Double, subShapeType: Int32 = 8) -> Int {
        Int(OCCTShapeToleranceInRangeCount(handle, min, max, subShapeType))
    }
}

extension Shape {
    /// Add missing 3D curve to an edge.
    ///
    /// Returns true if fixed.
    public static func fixEdgeAddCurve3d(_ edge: Shape) -> Bool {
        OCCTShapeFixEdgeAddCurve3d(edge.handle)
    }

    /// Add missing PCurve to an edge on a face.
    public static func fixEdgeAddPCurve(_ edge: Shape, face: Shape, isSeam: Bool = false) -> Bool {
        OCCTShapeFixEdgeAddPCurve(edge.handle, face.handle, isSeam)
    }

    /// Remove 3D curve from an edge.
    public static func fixEdgeRemoveCurve3d(_ edge: Shape) -> Bool {
        OCCTShapeFixEdgeRemoveCurve3d(edge.handle)
    }

    /// Remove PCurve from an edge on a face.
    public static func fixEdgeRemovePCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTShapeFixEdgeRemovePCurve(edge.handle, face.handle)
    }

    /// Fix reversed 2D curve on an edge/face pair.
    public static func fixEdgeReversed2d(_ edge: Shape, face: Shape) -> Bool {
        OCCTShapeFixEdgeFixReversed2d(edge.handle, face.handle)
    }
}
