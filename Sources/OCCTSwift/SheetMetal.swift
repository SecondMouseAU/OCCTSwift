import Foundation

/// Sheet-metal composition API.
///
/// Builds bent sheet-metal parts by extruding planar flanges along their sheet
/// normal, fusing them, then filleting the shared seam edges with the bend
/// radius. Each flange is a 2D profile in its own `(u, v)` plane; `Bend`
/// declares which pair of flanges meet and the inside radius of their bend.
///
/// OCCT has no sheet-metal bend primitive, `BRepFeat_Fold` and friends do not
/// exist. This namespace is the canonical composition of `Shape.extrude`,
/// `Shape.union`, and `Shape.filleted` that downstream consumers can drive
/// from a declarative description (see issue #85).
///
/// The reverse direction, unwrapping a bent sheet-metal solid to a flat
/// cutting pattern, is intended to live in this namespace as well; it is not
/// yet implemented.
///
/// ## Limitations
///
/// - **Bends apply a single radius to the seam edge as-is**, which in OCCT's
///   classification is the *outside* corner of an L-bracket (the outer
///   surface of the fold). The inner corner stays sharp. Real sheet-metal
///   parts want inner radius `r` and outer radius `r + thickness`; modeling
///   that requires a different construction and is not yet implemented. As
///   a consequence, `Bend.outsideRadius` and `Bend.materialThicknessAtBend`
///   are accepted (for forward compatibility) but not yet read anywhere in
///   `Builder.build()`; only `Bend.insideRadius` (the concave path's fillet
///   radius) and the Builder's global `thickness` (the convex path's
///   bend-material prism radius) affect the built shape (#1565).
/// - **Stepped seams (v0.151 limitation, lifted in v0.153)**, flanges
///   meeting along less than their full seam-direction extent (e.g. a narrow
///   upright on a wider base) now build cleanly. The builder splits the
///   wider flange at the seam-intersection endpoints before extruding;
///   the matched-extent middle piece carries the bend, and the outer
///   pieces stay flat. Issue #86.
public enum SheetMetal {

    /// A single sheet-metal flange: a closed 2D profile positioned in world
    /// space via `(origin, uAxis, vAxis)`, extruded along `normal` by the
    /// builder's `thickness`.
    ///
    /// `uAxis` and `vAxis` need not be derivable from `normal`, explicit
    /// control of all three axes lets you position a flange in any world
    /// orientation without handedness surprises. If `vAxis` is omitted, it is
    /// derived as `cross(normal, uAxis)`.
    public struct Flange: Sendable {
        public let id: String
        public let profile: [SIMD2<Double>]
        public let origin: SIMD3<Double>
        public let uAxis: SIMD3<Double>
        public let vAxis: SIMD3<Double>
        public let normal: SIMD3<Double>

        /// Lifting frame for `profile`, shared with `Sketch` and `FeatureReconstructor` (#972).
        ///
        /// Deliberately not `public`. `Placement` documents an *orthonormal* basis, and this one
        /// is not: `Flange` lets a caller supply any `uAxis`/`vAxis` (see the type's own doc
        /// comment), and `lift` has to keep scaling by them to match the `worldPoint` it replaced.
        /// Publishing it would hand callers a frame they are entitled to treat as unit.
        let placement: Placement

        public init(
            id: String,
            profile: [SIMD2<Double>],
            origin: SIMD3<Double>,
            normal: SIMD3<Double>,
            uAxis: SIMD3<Double>,
            vAxis: SIMD3<Double>? = nil
        ) {
            self.id = id
            self.profile = profile
            self.origin = origin
            self.uAxis = uAxis
            let n = Vector3DMath.normalize(normal) ?? normal
            self.normal = n
            self.vAxis = vAxis ?? Vector3DMath.cross(n, uAxis)
            self.placement = Placement(
                origin: origin, xAxis: uAxis, yAxis: self.vAxis, zAxis: n)
        }
    }

    /// Direction of a bend, measured from the metal's perspective.
    ///
    /// - `.concave`: the metal folds toward itself (interior dihedral < 180°).
    ///   Example: an L-bracket bend where the two flanges face each other.
    /// - `.convex`: the metal folds back on the opposite side (interior dihedral
    ///   > 180°, reflex angle). Example: a Z-section's middle bend, where the
    ///   third flange folds away from the first.
    /// - `.auto`: if the owning `Bend`'s `angle` is non-nil and non-zero, its sign decides
    ///   directly (positive → concave, negative → convex, matching `Bend.angle`'s own doc
    ///   comment), overriding geometric inference. Otherwise inferred from flange-body positions:
    ///   the Builder uses `concave` if the two flanges' body centroids sit on positions that make
    ///   the bend natural (b's centroid is on a's `+normal` side); else `convex`. Almost every
    ///   input matches the inference; explicitly specify `angle` or `direction` only when the
    ///   geometry is symmetric or you want to override.
    public enum BendDirection: Sendable, Equatable {
        case auto
        case concave
        case convex
    }

    /// A bend between two flanges, with full control over inside/outside
    /// radii, material thickness through the bend region, and a direction
    /// override.
    ///
    /// Sign conventions follow OCCT's right-hand rule:
    /// - `angle == 0` → flat continuation (metal extends straight, no bend).
    /// - `|angle| == π` → fully closed sheet (folded back on itself).
    /// - Sign of `angle`: positive for concave bends (L-shape from outside);
    ///   negative for convex bends (Z's back corner). `nil` means "infer
    ///   from the flange placements".
    ///
    /// This sign only drives `direction` resolution when `direction` is left at its default
    /// `.auto` (a non-nil, non-zero `angle` then overrides the geometric inference, see
    /// `BendDirection.auto`'s doc comment); an explicit `direction: .concave`/`.convex` always
    /// wins outright, whatever `angle` says. `angle` itself is not otherwise read: it does not
    /// currently constrain the fillet/bend-material geometry to that literal angle, only its sign
    /// (when used) picks concave vs. convex.
    ///
    /// `outsideRadius` and `materialThicknessAtBend` are accepted on every `Bend` for forward
    /// compatibility, but **neither is read by `Builder.build()` today**, unlike `angle`'s sign
    /// (see above), which is. The concave path always fillets the seam edge with `insideRadius`
    /// alone (OCCT's own single radius on that edge, see the file's top-level "Limitations"
    /// section), and the convex path's bend-material prism radius is always the Builder's global
    /// `thickness`, never `outsideRadius` or `materialThicknessAtBend`. Setting either field
    /// changes nothing about the built shape; a caller wanting an extruded-angle profile (sharp
    /// inside, rounded outside) or a thinned bend line (etched parts) cannot get that effect from
    /// this Builder yet.
    public struct Bend: Sendable {
        public let fromFlangeID: String
        public let toFlangeID: String

        /// Bend angle in radians.
        ///
        /// 0 = flat continuation, ±π = closed sheet. Positive = concave; negative = convex. `nil` = infer from
        /// flange placements. When `direction` is `.auto` (the default), a non-nil, non-zero
        /// `angle` decides concave vs. convex by this sign, overriding the geometric inference;
        /// set `direction` explicitly instead if you want to override `angle`'s sign too.
        public let angle: Double?

        /// Inside bend radius (the smaller, concave radius from inside the
        /// metal).
        ///
        /// Set to 0 for a sharp inside corner.
        public let insideRadius: Double

        /// Outside bend radius (the larger, convex radius from outside the
        /// metal).
        ///
        /// `nil` means use the natural sheet-metal default `insideRadius + materialThicknessAtBend`.
        ///
        /// **Not yet read by `Builder.build()`** (see `Bend`'s own doc comment above); setting
        /// this has no effect on the built shape today.
        public let outsideRadius: Double?

        /// Material thickness through the bend region.
        ///
        /// `nil` means use the Builder's global `thickness`. For etched parts, set to a
        /// fraction of the flange thickness.
        ///
        /// **Not yet read by `Builder.build()`** (see `Bend`'s own doc comment above); setting
        /// this has no effect on the built shape today.
        public let materialThicknessAtBend: Double?

        /// Explicit direction override; defaults to `.auto`.
        public let direction: BendDirection

        /// Backward-compatible init from v0.151+: `radius` becomes the
        /// inside bend radius.
        ///
        /// Outside radius defaults to `radius + thickness` (the sheet-metal-physics default). Direction is inferred.
        public init(from fromID: String, to toID: String, radius: Double) {
            self.fromFlangeID = fromID
            self.toFlangeID = toID
            self.insideRadius = radius
            self.outsideRadius = nil
            self.materialThicknessAtBend = nil
            self.angle = nil
            self.direction = .auto
        }

        /// Full init exposing all controls.
        public init(
            from fromID: String,
            to toID: String,
            angle: Double? = nil,
            insideRadius: Double,
            outsideRadius: Double? = nil,
            materialThicknessAtBend: Double? = nil,
            direction: BendDirection = .auto
        ) {
            self.fromFlangeID = fromID
            self.toFlangeID = toID
            self.angle = angle
            self.insideRadius = insideRadius
            self.outsideRadius = outsideRadius
            self.materialThicknessAtBend = materialThicknessAtBend
            self.direction = direction
        }

        /// Legacy alias, the `radius` you'd have passed to the
        /// pre-v0.155 init.
        ///
        /// Equal to `insideRadius`. Deprecated callers retain access without a migration. New callers should use the
        /// explicit `insideRadius`/`outsideRadius` fields.
        public var radius: Double { insideRadius }
    }

    public enum BuildError: Error, CustomStringConvertible {
        case invalidThickness(Double)
        case noFlanges
        case duplicateFlangeID(String)
        case unknownFlangeID(String)
        case invalidFlangeProfile(id: String)
        case flangeExtrusionFailed(id: String)
        case unionFailed
        case parallelFlangesHaveNoSeam(fromID: String, toID: String)
        case noSeamEdgeFound(fromID: String, toID: String)
        case filletFailed(fromID: String, toID: String, radius: Double)
        case seamsDoNotOverlap(fromID: String, toID: String)
        case nonRectangularStepFlange(id: String)

        public var description: String {
            switch self {
            case .invalidThickness(let t):
                return "SheetMetal: thickness must be > 0 (got \(t))"
            case .noFlanges:
                return "SheetMetal: at least one flange is required"
            case .duplicateFlangeID(let id):
                return "SheetMetal: duplicate flange id '\(id)'"
            case .unknownFlangeID(let id):
                return "SheetMetal: unknown flange id '\(id)' referenced by bend"
            case .invalidFlangeProfile(let id):
                return "SheetMetal: flange '\(id)' profile is invalid (need >=3 points)"
            case .flangeExtrusionFailed(let id):
                return "SheetMetal: failed to extrude flange '\(id)'"
            case .unionFailed:
                return "SheetMetal: boolean union of flanges failed"
            case .parallelFlangesHaveNoSeam(let a, let b):
                return "SheetMetal: flanges '\(a)' and '\(b)' are parallel, no bend seam"
            case .noSeamEdgeFound(let a, let b):
                return
                    "SheetMetal: no shared seam edge found between '\(a)' and '\(b)', check flange placement"
            case .filletFailed(let a, let b, let r):
                return "SheetMetal: fillet of radius \(r) between '\(a)' and '\(b)' failed"
            case .seamsDoNotOverlap(let a, let b):
                return
                    "SheetMetal: flanges '\(a)' and '\(b)' have no overlap along the seam direction"
            case .nonRectangularStepFlange(let id):
                return
                    "SheetMetal: flange '\(id)' has a stepped seam but a non-rectangular profile; step-aware bends require rectangular profiles in v0.153"
            }
        }
    }

    /// Composes a list of flanges and bends into a single bent `Shape`.
    public struct Builder: Sendable {
        public let thickness: Double

        public init(thickness: Double) {
            self.thickness = thickness
        }

        /// Build the bent sheet-metal part.
        ///
        /// 1. Validate inputs.
        /// 2. For each bend, compute the seam intersection along the seam
        ///    direction. If a flange's seam edge extends beyond the
        ///    intersection (a *stepped* seam, one flange wider than the
        ///    other along the seam), split that flange's profile at the
        ///    intersection endpoints, producing a matched-extent middle
        ///    piece + flat extensions.
        /// 3. Extrude each piece along its normal by `thickness`.
        /// 4. Fuse all pieces.
        /// 5. For each bend, locate the seam edge(s) between the
        ///    matched-extent pieces of the two flanges and apply a fillet
        ///    of the given radius.
        ///
        /// For matched-extent flanges, the result is identical to v0.151's
        /// behaviour. For stepped flanges, where v0.151 threw
        /// `BuildError.filletFailed`, v0.153 produces a clean bent solid.
        public func build(flanges: [Flange], bends: [Bend] = []) throws -> Shape {
            guard thickness > 0 else { throw BuildError.invalidThickness(thickness) }
            guard !flanges.isEmpty else { throw BuildError.noFlanges }

            var flangeByID: [String: Flange] = [:]
            for f in flanges {
                if flangeByID[f.id] != nil { throw BuildError.duplicateFlangeID(f.id) }
                if f.profile.count < 3 { throw BuildError.invalidFlangeProfile(id: f.id) }
                flangeByID[f.id] = f
            }
            for bend in bends {
                if flangeByID[bend.fromFlangeID] == nil {
                    throw BuildError.unknownFlangeID(bend.fromFlangeID)
                }
                if flangeByID[bend.toFlangeID] == nil {
                    throw BuildError.unknownFlangeID(bend.toFlangeID)
                }
            }

            // For each bend, gather seam direction + intersection geometry.
            var bendInfos: [BendIntersection] = []
            for bend in bends {
                let a = flangeByID[bend.fromFlangeID]!
                let b = flangeByID[bend.toFlangeID]!
                bendInfos.append(try Self.intersect(bend: bend, a: a, b: b))
            }

            // For each flange, compute split u-coordinates from all its
            // bends. A flange whose seam edge extends past a bend's
            // intersection is split at that intersection's endpoints.
            //
            // The resulting pieces preserve the flange's id (suffixed for
            // disambiguation) but each is a separate Flange used for
            // extrusion. The `matchedID` map remembers which piece carries
            // the bend so the post-union fillet only targets that piece's
            // seam edges.
            var pieces: [Flange] = []
            var matchedPieceID: [Int: (a: String, b: String)] = [:]
            for f in flanges {
                let splits = Self.collectSplitsFor(flange: f, bendInfos: bendInfos)
                if splits.isEmpty {
                    pieces.append(f)
                    Self.recordMatched(
                        for: f.id, asPieceID: f.id,
                        bendInfos: bendInfos,
                        matchedPieceID: &matchedPieceID)
                    continue
                }
                let split = try Self.splitFlange(f, splitsAlong: splits, bendInfos: bendInfos)
                pieces.append(contentsOf: split.pieces)
                for (bendIdx, pieceID) in split.matchedByBend {
                    if bendInfos[bendIdx].fromFlangeID == f.id {
                        let prevB = matchedPieceID[bendIdx]?.b ?? bendInfos[bendIdx].toFlangeID
                        matchedPieceID[bendIdx] = (a: pieceID, b: prevB)
                    } else if bendInfos[bendIdx].toFlangeID == f.id {
                        let prevA = matchedPieceID[bendIdx]?.a ?? bendInfos[bendIdx].fromFlangeID
                        matchedPieceID[bendIdx] = (a: prevA, b: pieceID)
                    }
                }
            }

            // Extrude each piece.
            var bodies: [String: Shape] = [:]
            for p in pieces {
                guard let body = Self.extrude(flange: p, thickness: thickness) else {
                    throw BuildError.flangeExtrusionFailed(id: p.id)
                }
                bodies[p.id] = body
            }

            var fused = bodies[pieces[0].id]!
            for p in pieces.dropFirst() {
                guard let next = fused.union(bodies[p.id]!) else {
                    throw BuildError.unionFailed
                }
                fused = next
            }

            // For each bend, classify direction (concave vs convex) and
            // dispatch to the appropriate construction:
            //
            //   concave, flange bodies overlap in volume around the bend
            //     (an L-bracket's natural shape). Fillet the inside seam
            //     edge with `bend.insideRadius`.
            //   convex, flange bodies only kiss along a line (a Z-section's
            //     back corner). The seam edge is non-manifold and cannot be
            //     filleted directly; instead, build a curved-triangle prism
            //     of bend material and fuse it in. The outer cylindrical
            //     face of the prism is the bend's rounded outside surface.
            for (i, bend) in bends.enumerated() {
                let aID = matchedPieceID[i]?.a ?? bend.fromFlangeID
                let bID = matchedPieceID[i]?.b ?? bend.toFlangeID
                guard let aPiece = pieces.first(where: { $0.id == aID }),
                    let bPiece = pieces.first(where: { $0.id == bID })
                else {
                    throw BuildError.unknownFlangeID(aID)
                }

                let seamDir = Vector3DMath.cross(aPiece.normal, bPiece.normal)
                guard let seamUnit = Vector3DMath.normalize(seamDir) else {
                    throw BuildError.parallelFlangesHaveNoSeam(
                        fromID: bend.fromFlangeID, toID: bend.toFlangeID)
                }

                let direction = Self.resolvedDirection(
                    bend: bend, a: aPiece, b: bPiece, thickness: thickness)

                switch direction {
                case .concave, .auto:
                    // Existing path. `auto` falls here only as a defensive
                    // default; resolvedDirection always returns concave or
                    // convex for non-trivial bends.
                    let seamEdges = Self.findSeamEdges(
                        in: fused, between: aPiece, and: bPiece,
                        seamUnit: seamUnit, thickness: thickness)
                    guard !seamEdges.isEmpty else {
                        throw BuildError.noSeamEdgeFound(
                            fromID: bend.fromFlangeID, toID: bend.toFlangeID)
                    }
                    guard
                        let filleted = fused.filleted(
                            edges: seamEdges, radius: bend.insideRadius)
                    else {
                        throw BuildError.filletFailed(
                            fromID: bend.fromFlangeID, toID: bend.toFlangeID,
                            radius: bend.insideRadius)
                    }
                    fused = filleted

                case .convex:
                    guard
                        let bendMaterial = Self.buildConvexBendMaterial(
                            bend: bend,
                            a: aPiece, b: bPiece,
                            bendIntersection: bendInfos[i],
                            seamUnit: seamUnit,
                            thickness: thickness)
                    else {
                        throw BuildError.filletFailed(
                            fromID: bend.fromFlangeID, toID: bend.toFlangeID,
                            radius: bend.insideRadius)
                    }
                    guard let merged = fused.union(bendMaterial) else {
                        throw BuildError.unionFailed
                    }
                    fused = merged
                }
            }

            return fused
        }

        private static func extrude(flange: Flange, thickness: Double) -> Shape? {
            let points3D = flange.profile.map { flange.placement.lift($0) }
            guard let wire = Wire.polygon3D(points3D, closed: true) else { return nil }
            return Shape.extrude(profile: wire, direction: flange.normal, length: thickness)
        }

        /// Resolve the bend direction.
        ///
        /// If the user pinned a direction explicitly, honour it. Otherwise, if `bend.angle` is
        /// non-nil and non-zero, its documented sign convention (positive = concave, negative =
        /// convex, see `Bend`'s doc comment) decides directly, overriding geometric inference; a
        /// caller who set `angle` gets exactly the direction the sign promises regardless of how
        /// the flange bodies happen to be placed. Otherwise (`angle` nil or `0`, which is
        /// documented as "flat continuation" and has no concave/convex sign of its own) infer from
        /// flange-body positions: a bend is concave when b's body centroid sits on a's `+normal`
        /// side (the two flanges' bodies overlap in volume around the seam, like an L-bracket);
        /// convex otherwise.
        fileprivate static func resolvedDirection(
            bend: Bend,
            a: Flange, b: Flange,
            thickness: Double
        ) -> BendDirection {
            switch bend.direction {
            case .concave: return .concave
            case .convex: return .convex
            case .auto:
                if let angle = bend.angle, angle != 0 {
                    return angle > 0 ? .concave : .convex
                }
                let midA = bodyMidpoint(of: a, thickness: thickness)
                let midB = bodyMidpoint(of: b, thickness: thickness)
                let projection = Vector3DMath.dot(midB - midA, a.normal)
                return projection > 0 ? .concave : .convex
            }
        }

        /// Build a curved-triangle bend-material prism for a convex bend.
        ///
        /// In a convex bend (e.g. a Z-section's middle bend), the two
        /// flange bodies touch at a single line, the "kiss line", but
        /// don't overlap in volume. Filleting that line directly is
        /// non-manifold (four boundary faces meet at the seam). Instead
        /// we add a curved-triangle prism that bridges the two flanges'
        /// outer-corner edges with a cylindrical fillet on the outside.
        ///
        /// Cross-section in the plane perpendicular to the seam:
        ///   • Vertex K, the kiss point (where the two flange profile
        ///     edges meet in 3D).
        ///   • Vertex A, flange a's outer-corner at the seam end. K
        ///     translated by `a.normal · thickness` along a's body
        ///     extrusion direction.
        ///   • Vertex C, flange b's outer-corner at the seam end.
        ///   • Edges: K→A (line, lying on a's seam-end face), K→C (line,
        ///     lying on b's seam-end face), C→A (arc of radius |KA|,
        ///     centred at K, curving through the open quadrant, the
        ///     "outside" of the bend).
        ///
        /// The natural arc radius is the distance from the kiss point to
        /// each flange's outer corner, which equals the flange thickness
        /// for sheet metal of uniform thickness. This is the radius of
        /// the rounded outside surface of the bend. The "inside" of the
        /// bend (at the kiss point) stays sharp, for a fully-rounded
        /// inside, the caller would need flange placements that leave
        /// room for the inside cylinder, which is a CAD-design choice
        /// rather than a shortcoming of this builder.
        ///
        /// Returns nil if the geometry can't be constructed (e.g. flange
        /// thicknesses differ or the kiss point can't be located).
        fileprivate static func buildConvexBendMaterial(
            bend: Bend,
            a: Flange, b: Flange,
            bendIntersection: BendIntersection,
            seamUnit: SIMD3<Double>,
            thickness: Double
        ) -> Shape? {
            // Kiss line: the two flange profile end-edges meet on this
            // line in 3D. Use the bend intersection's seam range to find
            // the segment.
            //
            // For each flange, the seam edge is at a specific u
            // coordinate (= u=0 or u=max in flange profile coords). The
            // BendIntersection records this via aSeamAlongU / bSeamAlongU
            // and the flange's outer wire bounds.
            //
            // Simpler approach: walk a's profile edges and find the one
            // whose lifted points are on the seam line (parallel to
            // seamUnit).
            guard
                let (kissStart, kissEnd) = seamSegment(
                    of: a, seamUnit: seamUnit, otherFlange: b, tolerance: 1e-4)
            else { return nil }

            // Flange-a outer face direction = `+a.normal` displaced by
            // thickness from a.origin's plane. The outer-corner offset
            // from the kiss line is `thickness · a.normal` (a's body
            // extrudes in +a.normal direction; the outer face is at the
            // far end of that extrusion).
            let aOuterOffset = thickness * a.normal
            let bOuterOffset = thickness * b.normal

            // Only the v=0 (kissStart) cross-section is constructed; the far end at
            // kissEnd falls out of the extrusion along the seam below.
            let aOuter0 = kissStart + aOuterOffset
            let bOuter0 = kissStart + bOuterOffset

            // Wire for the cross-section at v=0 (kissStart end). Three
            // edges: line K→A, line K→C, arc C→A.
            let radius = Vector3DMath.modulus(aOuter0 - kissStart)
            // Sanity: |a outer offset| should equal |b outer offset|
            // (uniform-thickness assumption).
            let radiusB = Vector3DMath.modulus(bOuter0 - kissStart)
            if abs(radius - radiusB) > 1e-4 * max(radius, radiusB) {
                return nil
            }
            // The arc must curve through the "open" quadrant of the bend, the side
            // opposite to where the flanges' bodies sit. Rather than pick an arc-plane
            // normal and derive a traversal sign from it, the arc is built through three
            // points (start → midpoint → end) below, so the midpoint alone fixes the
            // curvature direction.
            let aDir = Vector3DMath.normalize(aOuter0 - kissStart) ?? SIMD3(0, 0, 0)
            let cDir = Vector3DMath.normalize(bOuter0 - kissStart) ?? SIMD3(0, 0, 0)
            // The "expected" arc midpoint direction = (aDir + cDir)/2,
            // normalised, pointing from kiss into the open quadrant.
            let bisectorRaw = aDir + cDir
            let bisectorLen = Vector3DMath.modulus(bisectorRaw)
            guard bisectorLen > 1e-9 else { return nil }
            let bisector = bisectorRaw / bisectorLen
            let midpointTarget = kissStart + radius * bisector

            // Try arc with normal = +seamUnit and 3-points (start=A, mid=midpointTarget, end=C).
            // 3-point arc API takes start, midpoint, end and computes the rest.
            // Use Curve3D bridge through a Wire convenience.
            let arcWire = arcWireThroughThreePoints(
                start: aOuter0, mid: midpointTarget, end: bOuter0)
            guard let arc = arcWire else { return nil }

            // Lines K→A, K→C.
            guard let lineKA = Wire.line(from: kissStart, to: aOuter0) else { return nil }
            guard let lineKC = Wire.line(from: kissStart, to: bOuter0) else { return nil }

            // Compose the wire: K→A→arc→C→K.
            // Wire.join concatenates wires that share endpoints.
            // Order: A→K (reverse of K→A) → K→C → arc(C→A).
            // Easier: use OCCT's wireFromEdges with explicit edge ordering.
            // For now: try Wire.join on [lineKA, lineKC, arc].
            // OCCT's join may not care about direction.
            let crossSectionWire = Wire.join([lineKA, lineKC, arc])
            guard let wire = crossSectionWire else { return nil }

            guard let face = Shape.face(from: wire, planar: true) else { return nil }

            // Extrude the cross-section face along the seam. `extruded(by:)` takes the full
            // vector (direction and length together), unlike
            // `Shape.extrude(profile:direction:length:)`, which wants a wire profile rather
            // than the face we have here.
            let extrudeVec = (kissEnd - kissStart)
            return face.extruded(by: extrudeVec)
        }

        /// Build a 3-point arc wire (start → mid → end) using OCCT's
        /// `GC_MakeArcOfCircle`.
        ///
        /// The midpoint determines the arc's curvature direction.
        fileprivate static func arcWireThroughThreePoints(
            start: SIMD3<Double>,
            mid: SIMD3<Double>,
            end: SIMD3<Double>
        ) -> Wire? {
            return Wire.arc(start: start, midpoint: mid, end: end)
        }

        /// Find the seam segment for flange `a` opposite flange `b`.
        ///
        /// Returns the two endpoints of the kiss line in 3D.
        ///
        /// Walks `a`'s profile end-edge (the edge of the profile that
        /// lies on the seam line, identified by edges parallel to
        /// `seamUnit`). For a rectangular profile there are typically
        /// two candidate edges (one at u=0, one at u=max); we pick the
        /// one closest to flange `b`'s body.
        fileprivate static func seamSegment(
            of a: Flange,
            seamUnit: SIMD3<Double>,
            otherFlange b: Flange,
            tolerance: Double
        ) -> (SIMD3<Double>, SIMD3<Double>)? {
            // Walk a's profile in 2D. Find edges (between consecutive
            // profile points) whose 3D direction is parallel to seamUnit.
            // Two such edges typically; pick the one whose midpoint is
            // closest to b's body centroid.
            let n = a.profile.count
            guard n >= 3 else { return nil }
            var candidates: [(start: SIMD3<Double>, end: SIMD3<Double>)] = []
            for i in 0..<n {
                let p1 = a.placement.lift(a.profile[i])
                let p2 = a.placement.lift(a.profile[(i + 1) % n])
                let dir = p2 - p1
                guard let dirUnit = Vector3DMath.normalize(dir) else { continue }
                if abs(abs(Vector3DMath.dot(dirUnit, seamUnit)) - 1.0) < tolerance {
                    candidates.append((p1, p2))
                }
            }
            guard !candidates.isEmpty else { return nil }
            // Pick closest to b's body centroid.
            let bCentroid = bodyMidpoint(of: b, thickness: 0)
            let chosen = candidates.min(by: { c1, c2 in
                let m1 = (c1.start + c1.end) * 0.5
                let m2 = (c2.start + c2.end) * 0.5
                return Vector3DMath.modulus(m1 - bCentroid) < Vector3DMath.modulus(m2 - bCentroid)
            })!
            return chosen
        }

        /// Find the seam edge(s) between two flanges in the fused shape.
        ///
        /// The bend sits at the intersection of two specific faces, each
        /// flange's face pointing *toward* the other. Every other edge where
        /// the two flange planes cross (the convex back corner of an L, for
        /// instance) lies on the opposite pair of faces, so the toward-plane
        /// test uniquely selects the bend.
        ///
        /// Note: OCCT classifies an L-bracket's bend edge as CONVEX (looking
        /// from outside the solid, you turn outward around it). We do not use
        /// `edgeConcavities`, it splits along-bend behavior by orientation
        /// and does not help discriminate here.
        private static func findSeamEdges(
            in shape: Shape,
            between a: Flange, and b: Flange,
            seamUnit: SIMD3<Double>,
            thickness: Double
        ) -> [Edge] {
            let parallelTol = 1e-4
            let planeTol = max(1e-6, thickness * 1e-4)

            // Each flange's "toward-other" face is the one its body midpoint
            // is farther from (i.e., the face the other flange sits beside).
            let midA = bodyMidpoint(of: a, thickness: thickness)
            let midB = bodyMidpoint(of: b, thickness: thickness)
            let aTowardB: Double =
                Vector3DMath.dot(midB - a.origin, a.normal) > thickness * 0.5 ? thickness : 0
            let bTowardA: Double =
                Vector3DMath.dot(midA - b.origin, b.normal) > thickness * 0.5 ? thickness : 0

            return shape.edges().filter { edge in
                guard edge.isLine else { return false }
                let (start, end) = edge.endpoints
                let edgeVec = end - start
                guard let edgeUnit = Vector3DMath.normalize(edgeVec) else { return false }

                let dot = Vector3DMath.dot(edgeUnit, seamUnit)
                if abs(abs(dot) - 1.0) > parallelTol { return false }

                let mid = (start + end) * 0.5
                let dA = Vector3DMath.dot(mid - a.origin, a.normal)
                let dB = Vector3DMath.dot(mid - b.origin, b.normal)
                return abs(dA - aTowardB) < planeTol && abs(dB - bTowardA) < planeTol
            }
        }

        private static func bodyMidpoint(of flange: Flange, thickness: Double) -> SIMD3<Double> {
            var sum = SIMD3<Double>(repeating: 0)
            for p in flange.profile { sum += flange.placement.lift(p) }
            let profileCenter = sum / Double(flange.profile.count)
            return profileCenter + 0.5 * thickness * flange.normal
        }

        // MARK: - Step-aware bend support (#86, v0.153)

        /// Geometry of a single bend: which flanges, the seam direction in
        /// 3D, and each flange's seam-edge extent in its own profile axis
        /// that's parallel to `seamUnit`.
        fileprivate struct BendIntersection {
            let bend: Bend
            let fromFlangeID: String
            let toFlangeID: String
            let radius: Double
            let seamUnit: SIMD3<Double>
            /// Which of flange A's profile axes the seam direction aligns with.
            ///
            /// `true` for `uAxis`, `false` for `vAxis`. Meaningless (and unread) when the seam
            /// aligns with neither, the "no split" fallback below (#1565).
            let aSeamAlongU: Bool
            let bSeamAlongU: Bool
            /// A's seam-edge profile-coord range along its split axis.
            let aRange: ClosedRange<Double>
            let bRange: ClosedRange<Double>
            /// Intersection range along the seam line, in A's split-axis
            /// profile coords (since seam direction = A's uAxis or vAxis,
            /// the intersection projects directly onto that axis).
            let aIntersection: ClosedRange<Double>
            let bIntersection: ClosedRange<Double>
        }

        fileprivate struct SplitResult {
            let pieces: [Flange]
            /// For each bend index that touches this flange, which piece id
            /// is the matched-extent piece (carries the bend).
            let matchedByBend: [Int: String]
        }

        /// Compute seam direction and intersection range between two
        /// rectangular flanges.
        ///
        /// Falls back to "no split needed" when the seam direction doesn't align with either flange's u or v axis,
        /// that case continues to use the v0.151 single-fillet path with no flange splitting.
        fileprivate static func intersect(bend: Bend, a: Flange, b: Flange) throws
            -> BendIntersection
        {
            let seamDir = Vector3DMath.cross(a.normal, b.normal)
            guard let seamUnit = Vector3DMath.normalize(seamDir) else {
                throw BuildError.parallelFlangesHaveNoSeam(
                    fromID: bend.fromFlangeID, toID: bend.toFlangeID)
            }
            let aAlongU = Self.axisParallel(seamUnit, to: a.uAxis)
            let aAlongV = Self.axisParallel(seamUnit, to: a.vAxis)
            let bAlongU = Self.axisParallel(seamUnit, to: b.uAxis)
            let bAlongV = Self.axisParallel(seamUnit, to: b.vAxis)
            let aSeamAlongU = aAlongU
            let bSeamAlongU = bAlongU
            let aRange = Self.profileRange(of: a, alongU: aSeamAlongU)
            let bRange = Self.profileRange(of: b, alongU: bSeamAlongU)

            // If either flange's seam direction aligns with neither its own u nor v axis, there's
            // no meaningful profile-coordinate axis to project the seam intersection onto for
            // that flange (the doc comment above documents exactly this as a "no split" fallback).
            // Return unsplit (full-extent) ranges for both flanges rather than projecting onto a
            // profile axis the seam isn't actually parallel to, which `collectSplitsFor` reads as
            // "this bend needs no split", the v0.151 single-fillet path.
            guard aAlongU || aAlongV, bAlongU || bAlongV else {
                return BendIntersection(
                    bend: bend,
                    fromFlangeID: bend.fromFlangeID,
                    toFlangeID: bend.toFlangeID,
                    radius: bend.radius,
                    seamUnit: seamUnit,
                    aSeamAlongU: aSeamAlongU,
                    bSeamAlongU: bSeamAlongU,
                    aRange: aRange,
                    bRange: bRange,
                    aIntersection: aRange,
                    bIntersection: bRange)
            }

            let aProfileAxis = aSeamAlongU ? a.uAxis : a.vAxis
            let bProfileAxis = bSeamAlongU ? b.uAxis : b.vAxis

            // Linear map between flange profile coord (along its seam axis)
            // and seam-line projection. The map is `proj(u) = aOriginProj +
            // u * aAxisProj` where aAxisProj is the dot of the profile axis
            // with seamUnit (±1 for parallel/antiparallel, bigger range
            // here is just defensive). Using a.origin as the seam-line
            // reference lets us compare both flanges' projections directly.
            let reference = a.origin
            let aOriginProj = Vector3DMath.dot(a.origin - reference, seamUnit)
            let bOriginProj = Vector3DMath.dot(b.origin - reference, seamUnit)
            let aAxisProj = Vector3DMath.dot(aProfileAxis, seamUnit)
            let bAxisProj = Vector3DMath.dot(bProfileAxis, seamUnit)
            // Defensive, `axisParallel` already guarantees |aAxisProj| ≈ 1.
            guard abs(aAxisProj) > 1e-6, abs(bAxisProj) > 1e-6 else {
                throw BuildError.seamsDoNotOverlap(
                    fromID: bend.fromFlangeID, toID: bend.toFlangeID)
            }

            let aProj0 = aOriginProj + aRange.lowerBound * aAxisProj
            let aProj1 = aOriginProj + aRange.upperBound * aAxisProj
            let bProj0 = bOriginProj + bRange.lowerBound * bAxisProj
            let bProj1 = bOriginProj + bRange.upperBound * bAxisProj
            let lo = max(min(aProj0, aProj1), min(bProj0, bProj1))
            let hi = min(max(aProj0, aProj1), max(bProj0, bProj1))
            guard hi - lo > 1e-9 else {
                throw BuildError.seamsDoNotOverlap(
                    fromID: bend.fromFlangeID, toID: bend.toFlangeID)
            }

            // Inverse map: u(proj) = (proj - originProj) / axisProj.
            let aIntLow = (lo - aOriginProj) / aAxisProj
            let aIntHigh = (hi - aOriginProj) / aAxisProj
            let aIntersection = min(aIntLow, aIntHigh)...max(aIntLow, aIntHigh)
            let bIntLow = (lo - bOriginProj) / bAxisProj
            let bIntHigh = (hi - bOriginProj) / bAxisProj
            let bIntersection = min(bIntLow, bIntHigh)...max(bIntLow, bIntHigh)

            return BendIntersection(
                bend: bend,
                fromFlangeID: bend.fromFlangeID,
                toFlangeID: bend.toFlangeID,
                radius: bend.radius,
                seamUnit: seamUnit,
                aSeamAlongU: aSeamAlongU,
                bSeamAlongU: bSeamAlongU,
                aRange: aRange,
                bRange: bRange,
                aIntersection: aIntersection,
                bIntersection: bIntersection)
        }

        private static func axisParallel(_ a: SIMD3<Double>, to b: SIMD3<Double>) -> Bool {
            guard let an = Vector3DMath.normalize(a),
                let bn = Vector3DMath.normalize(b)
            else { return false }
            return abs(abs(Vector3DMath.dot(an, bn)) - 1.0) < 1e-6
        }

        /// Range of the rectangular profile along its u-axis (if `alongU`)
        /// or v-axis (otherwise).
        ///
        /// For a 4-vertex rectangle with axis-aligned edges, this is just `[min, max]` of the corresponding
        /// component.
        private static func profileRange(of f: Flange, alongU: Bool) -> ClosedRange<Double> {
            let coords: [Double] = alongU ? f.profile.map(\.x) : f.profile.map(\.y)
            return (coords.min() ?? 0)...(coords.max() ?? 0)
        }

        /// For a flange, return the split coordinates along whichever axis
        /// the bends' seams are aligned with.
        ///
        /// Splits are added at any bend's intersection endpoint that falls strictly inside the
        /// flange's seam range. Sorted, deduplicated.
        fileprivate static func collectSplitsFor(
            flange f: Flange,
            bendInfos: [BendIntersection]
        ) -> [(axis: SplitAxis, value: Double)] {
            var out: [(SplitAxis, Double)] = []
            for info in bendInfos {
                if info.fromFlangeID == f.id {
                    let axis: SplitAxis = info.aSeamAlongU ? .u : .v
                    let range = info.aRange
                    let lo = info.aIntersection.lowerBound
                    let hi = info.aIntersection.upperBound
                    if lo > range.lowerBound + 1e-9 { out.append((axis, lo)) }
                    if hi < range.upperBound - 1e-9 { out.append((axis, hi)) }
                }
                if info.toFlangeID == f.id {
                    let axis: SplitAxis = info.bSeamAlongU ? .u : .v
                    let range = info.bRange
                    let lo = info.bIntersection.lowerBound
                    let hi = info.bIntersection.upperBound
                    if lo > range.lowerBound + 1e-9 { out.append((axis, lo)) }
                    if hi < range.upperBound - 1e-9 { out.append((axis, hi)) }
                }
            }
            return out
        }

        fileprivate enum SplitAxis { case u, v }

        /// Split a rectangular flange along the given splits and identify
        /// which sub-piece carries each bend (the one spanning the bend's
        /// intersection range).
        fileprivate static func splitFlange(
            _ f: Flange,
            splitsAlong splits: [(axis: SplitAxis, value: Double)],
            bendInfos: [BendIntersection]
        ) throws -> SplitResult {
            guard f.profile.count == 4,
                Self.isAxisAlignedRect(f.profile)
            else {
                throw BuildError.nonRectangularStepFlange(id: f.id)
            }
            let uMin = f.profile.map(\.x).min()!
            let uMax = f.profile.map(\.x).max()!
            let vMin = f.profile.map(\.y).min()!
            let vMax = f.profile.map(\.y).max()!

            let uCuts = ([uMin] + splits.filter { $0.axis == .u }.map(\.value) + [uMax])
                .sorted()
                .reduce(into: [Double]()) { acc, val in
                    if acc.last.map({ abs($0 - val) > 1e-9 }) ?? true { acc.append(val) }
                }
            let vCuts = ([vMin] + splits.filter { $0.axis == .v }.map(\.value) + [vMax])
                .sorted()
                .reduce(into: [Double]()) { acc, val in
                    if acc.last.map({ abs($0 - val) > 1e-9 }) ?? true { acc.append(val) }
                }

            var pieces: [Flange] = []
            var pieceCells:
                [(piece: Flange, uRange: ClosedRange<Double>, vRange: ClosedRange<Double>)] = []
            var first = true
            for i in 0..<(uCuts.count - 1) {
                for j in 0..<(vCuts.count - 1) {
                    let u0 = uCuts[i]
                    let u1 = uCuts[i + 1]
                    let v0 = vCuts[j]
                    let v1 = vCuts[j + 1]
                    let pieceProfile: [SIMD2<Double>] = [
                        SIMD2(u0, v0), SIMD2(u1, v0), SIMD2(u1, v1), SIMD2(u0, v1),
                    ]
                    let pieceID = first ? f.id : "\(f.id)__split_\(i)_\(j)"
                    first = false
                    let piece = Flange(
                        id: pieceID,
                        profile: pieceProfile,
                        origin: f.origin,
                        normal: f.normal,
                        uAxis: f.uAxis,
                        vAxis: f.vAxis)
                    pieces.append(piece)
                    pieceCells.append((piece: piece, uRange: u0...u1, vRange: v0...v1))
                }
            }

            // For each bend touching this flange, find the piece whose
            // profile range matches the bend's intersection range.
            var matchedByBend: [Int: String] = [:]
            for (i, info) in bendInfos.enumerated() {
                let touchesAsA = info.fromFlangeID == f.id
                let touchesAsB = info.toFlangeID == f.id
                guard touchesAsA || touchesAsB else { continue }
                let alongU = touchesAsA ? info.aSeamAlongU : info.bSeamAlongU
                let intersection = touchesAsA ? info.aIntersection : info.bIntersection
                for cell in pieceCells {
                    let cellRange = alongU ? cell.uRange : cell.vRange
                    if abs(cellRange.lowerBound - intersection.lowerBound) < 1e-9
                        && abs(cellRange.upperBound - intersection.upperBound) < 1e-9
                    {
                        matchedByBend[i] = cell.piece.id
                        break
                    }
                }
            }
            return SplitResult(pieces: pieces, matchedByBend: matchedByBend)
        }

        /// Find the piece whose u-or-v range contains the bend's
        /// intersection range; mark it as the matched piece for `bendIdx`.
        fileprivate static func recordMatched(
            for flangeID: String,
            asPieceID pieceID: String,
            bendInfos: [BendIntersection],
            matchedPieceID: inout [Int: (a: String, b: String)]
        ) {
            for (i, info) in bendInfos.enumerated() {
                if info.fromFlangeID == flangeID {
                    let prevB = matchedPieceID[i]?.b ?? info.toFlangeID
                    matchedPieceID[i] = (a: pieceID, b: prevB)
                }
                if info.toFlangeID == flangeID {
                    let prevA = matchedPieceID[i]?.a ?? info.fromFlangeID
                    matchedPieceID[i] = (a: prevA, b: pieceID)
                }
            }
        }

        private static func isAxisAlignedRect(_ profile: [SIMD2<Double>]) -> Bool {
            guard profile.count == 4 else { return false }
            // Check that consecutive edges alternate along u and v axes.
            for i in 0..<4 {
                let p0 = profile[i]
                let p1 = profile[(i + 1) % 4]
                let dx = abs(p1.x - p0.x)
                let dy = abs(p1.y - p0.y)
                let alongU = dx > 1e-9 && dy < 1e-9
                let alongV = dy > 1e-9 && dx < 1e-9
                if !alongU && !alongV { return false }
            }
            return true
        }
    }
}
