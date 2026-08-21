import Foundation
import OCCTBridge
import simd

extension Shape {

    public static func + (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.union(rhs)
    }

    public static func - (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.subtracting(rhs)
    }

    public static func & (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.intersection(rhs)
    }

    /// Return a copy of this solid whose faces are oriented outward (positive
    /// volume).
    ///
    /// Some constructors, notably ``sweep(profile:along:)``
    /// (`BRepOffsetAPI_MakePipe`), can produce a geometrically correct solid whose
    /// faces point inward, so ``signedVolume`` comes back negative. That is a latent
    /// hazard for booleans and any `volume > 0` validation. This reverses the
    /// orientation when, and only when, the signed volume is negative; a solid that
    /// is already forward-oriented (or a shell/face with no enclosed volume) is
    /// returned unchanged.
    ///
    /// This reads ``signedVolume``, which is the flux integral rather than the strict volume, so it
    /// still normalises an open shell such as a pipe sweep. A strict volume test would report
    /// nothing there and quietly stop normalising the exact case #170 was filed about.
    ///
    /// - Returns: An outward-oriented copy, `self` when no fix is needed, or nil if
    ///   reversal fails.
    public func orientedForward() -> Shape? {
        signedVolume < 0 ? reversed : self
    }
    // MARK: - Selective Fillet

    /// Result of a fillet call that also reports which requested edges OCCT declined (#639).
    ///
    /// `BRepFilletAPI_MakeFillet::Add` silently does nothing for an edge it cannot fillet, most
    /// commonly a free-boundary edge of an open shell, which has only one adjacent face where a
    /// fillet needs two. So the plain fillet methods (``filleted(edges:radius:)``,
    /// ``filleted(edges:startRadius:endRadius:)``, ``filletEvolving(_:)``) build successfully and
    /// silently skip it. `FilletResult` is how a caller who used the `WithReport` sibling of one of
    /// those methods finds out which ones and how many.
    ///
    /// There is no *reason* to go with the list: `Add` returns nothing, and
    /// `BRepFilletAPI_MakeFillet::NbFaultyContours()`/`BadShape()`/`StripeStatus()` describe a
    /// contour that failed during `Build()`, which an edge OCCT never added to any contour never
    /// reaches. `Contour(edge) == 0`, populated by `Add()` and not `Build()`, is the only signal
    /// OCCT itself exposes, so this reports *which* edges were declined, not *why*.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let faces = box.faces().dropFirst().compactMap { Shape.fromFace($0) }   // drop one face
    /// let shell = Shape.sew(shapes: Array(faces))!                            // -> an open shell
    /// if let report = shell.filletedWithReport(edges: shell.edges(), radius: 1.0) {
    ///     print(report.declinedEdgeIndices)   // e.g. [6, 9, 10, 11]: skipped, not an error
    /// }
    /// ```
    public struct FilletResult: Sendable {
        /// The filleted shape.
        ///
        /// Identical to what the non-reporting sibling returns for the same input: this reports
        /// skipped edges, it does not reject the call over them.
        public let shape: Shape
        /// 0-based indices, matching ``Edge/index``, of the requested edges OCCT declined to
        /// fillet.
        ///
        /// Empty when every requested edge was accepted.
        ///
        /// This mirrors the request list rather than deduplicating it: naming the same declined
        /// edge twice reports it twice, so the count matches how many entries of the caller's list
        /// were refused. Use `Set(declinedEdgeIndices)` for distinct edges.
        public let declinedEdgeIndices: [Int]
        /// 0-based edge indices, matching ``Edge/index``, whose radius a *later* entry in the same
        /// request overwrote (#633).
        ///
        /// Empty for every `WithReport` sibling except ``Shape/blendedEdgesWithReport(_:)``, the
        /// one entry point that takes a per-edge radius array where naming an edge twice is even
        /// possible.
        ///
        /// `BRepFilletAPI_MakeFillet::Add(radius, edge)` resolves the edge's own slot within its
        /// contour and writes there, so a second `Add` on the same edge silently replaces the first
        /// radius rather than erroring or combining the two. This mirrors the request list, the
        /// same convention as `declinedEdgeIndices`: an edge index requested three times reports
        /// two overwritten entries here (the two radii that lost), not one. Use
        /// `Set(overwrittenDuplicateIndices)` for distinct edges.
        public let overwrittenDuplicateIndices: [Int]

        /// Explicit rather than the synthesized memberwise init, and the reason is this method,
        /// not the three that came before it.
        ///
        /// A `let` property with a default value is dropped from Swift's synthesized memberwise
        /// init entirely: it is not an overridable parameter the way a `var` with a default is, so
        /// a caller **cannot pass it at all**.
        ///
        /// The three existing `WithReport` call sites would have compiled unchanged against the
        /// synthesized init, silently taking the `[]` default, since none of them has anything to
        /// say about a duplicate index. `blendedEdgesWithReport(_:)` is the first caller that needs
        /// to pass a **non-default** value, and that is what the synthesized init structurally
        /// cannot express.
        public init(
            shape: Shape, declinedEdgeIndices: [Int], overwrittenDuplicateIndices: [Int] = []
        ) {
            self.shape = shape
            self.declinedEdgeIndices = declinedEdgeIndices
            self.overwrittenDuplicateIndices = overwrittenDuplicateIndices
        }
    }

    /// Fillet specific edges with uniform radius.
    ///
    /// Every edge must belong to this shape: only ``Edge/index`` is carried across, so an edge
    /// whose index names nothing here rejects the whole call rather than being skipped.
    ///
    /// ```swift
    /// let bracket = Shape.box(width: 40, height: 20, depth: 10)!
    /// let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 2)
    /// ```
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - radius: Fillet radius; must be > 0
    /// - Returns: Filleted shape, or nil on failure, including when the list names an edge that is not
    ///   this shape's.
    public func filleted(edges: [Edge], radius: Double) -> Shape? {
        guard !edges.isEmpty, radius > 0 else { return nil }

        // Extract indices from edges
        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard
                let result = OCCTShapeFilletEdges(
                    handle, buffer.baseAddress, Int32(indices.count), radius, nil, nil)
            else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// ``filleted(edges:radius:)``, also reporting which requested edges OCCT declined (#639).
    ///
    /// An edge OCCT cannot fillet is still skipped, not rejected: this changes only what a caller
    /// can learn about it, not the shape returned. See ``FilletResult`` for why the report is a
    /// list of indices rather than a count or a reason.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// if let report = box.filletedWithReport(edges: box.edges(), radius: 1.0) {
    ///     precondition(report.declinedEdgeIndices.isEmpty)   // every edge of a closed solid fillets
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - radius: Fillet radius; must be > 0
    /// - Returns: A ``FilletResult``, or nil on failure, including when the list names an edge that is not
    ///   this shape's.
    public func filletedWithReport(edges: [Edge], radius: Double) -> FilletResult? {
        guard !edges.isEmpty, radius > 0 else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer -> FilletResult? in
            var declined = [Int32](repeating: 0, count: indices.count)
            var declinedCount: Int32 = 0
            let result: OCCTShapeRef? = declined.withUnsafeMutableBufferPointer { declinedBuffer in
                OCCTShapeFilletEdges(
                    handle, buffer.baseAddress, Int32(indices.count), radius,
                    declinedBuffer.baseAddress, &declinedCount)
            }
            guard let result else { return nil }
            let declinedIndices = declined.prefix(Int(declinedCount)).map { Int($0) }
            return FilletResult(shape: Shape(handle: result), declinedEdgeIndices: declinedIndices)
        }
    }

    /// Fillet specific edges with linear radius interpolation.
    ///
    /// Every edge must belong to this shape, on the same all-or-nothing basis as
    /// ``filleted(edges:radius:)``.
    ///
    /// ```swift
    /// let bar = Shape.box(width: 40, height: 20, depth: 10)!
    /// let tapered = bar.filleted(edges: [bar.edges()[0]], startRadius: 1, endRadius: 3)
    /// ```
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - startRadius: Radius at start of each edge; must be > 0
    ///   - endRadius: Radius at end of each edge; must be > 0
    /// - Returns: Filleted shape, or nil on failure, including when the list names an edge that is not
    ///   this shape's.
    public func filleted(edges: [Edge], startRadius: Double, endRadius: Double) -> Shape? {
        guard !edges.isEmpty, startRadius > 0, endRadius > 0 else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard
                let result = OCCTShapeFilletEdgesLinear(
                    handle, buffer.baseAddress, Int32(indices.count), startRadius, endRadius, nil,
                    nil)
            else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// ``filleted(edges:startRadius:endRadius:)``, also reporting which requested edges OCCT
    /// declined (#639).
    ///
    /// See ``filletedWithReport(edges:radius:)`` for the reporting contract.
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - startRadius: Radius at start of each edge; must be > 0
    ///   - endRadius: Radius at end of each edge; must be > 0
    /// - Returns: A ``FilletResult``, or nil on failure, including when the list names an edge that is not
    ///   this shape's.
    public func filletedWithReport(edges: [Edge], startRadius: Double, endRadius: Double)
        -> FilletResult?
    {
        guard !edges.isEmpty, startRadius > 0, endRadius > 0 else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer -> FilletResult? in
            var declined = [Int32](repeating: 0, count: indices.count)
            var declinedCount: Int32 = 0
            let result: OCCTShapeRef? = declined.withUnsafeMutableBufferPointer { declinedBuffer in
                OCCTShapeFilletEdgesLinear(
                    handle, buffer.baseAddress, Int32(indices.count),
                    startRadius, endRadius,
                    declinedBuffer.baseAddress, &declinedCount)
            }
            guard let result else { return nil }
            let declinedIndices = declined.prefix(Int(declinedCount)).map { Int($0) }
            return FilletResult(shape: Shape(handle: result), declinedEdgeIndices: declinedIndices)
        }
    }

    // MARK: - Draft Angle

    /// Add draft angle to faces for mold release.
    ///
    /// Draft angles are used in injection molding and casting to allow parts to
    /// be released from the mold. The angle is measured from the pull direction.
    ///
    /// - Note: Every face must be one of *this* shape's, by index. A `Face` whose `index` names no
    ///   face here fails the whole call rather than being skipped (#568). It used to be dropped,
    ///   and `BRepOffsetAPI_DraftAngle` reports success for a request it was handed no faces for at
    ///   all, so a draft naming only faces from another shape returned this shape undrafted.
    ///
    /// - Parameters:
    ///   - faces: Faces to add draft to (must have valid indices from this shape)
    ///   - direction: Pull direction (typically vertical, e.g., [0, 0, 1])
    ///   - angle: Draft angle in radians (typically 1-5 degrees)
    ///   - neutralPlane: Plane where draft angle is zero (point and normal)
    /// - Returns: Drafted shape, or nil on failure
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 30)!
    /// let sides = box.faces().filter { $0.isVertical() }
    /// let drafted = box.drafted(
    ///     faces: sides,
    ///     direction: SIMD3(0, 0, 1),
    ///     angle: 3.0 * .pi / 180.0,
    ///     neutralPlane: (point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
    /// )
    /// ```
    public func drafted(
        faces: [Face],
        direction: SIMD3<Double>,
        angle: Double,
        neutralPlane: (point: SIMD3<Double>, normal: SIMD3<Double>)
    ) -> Shape? {
        guard !faces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(faces.count)
        for face in faces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard
                let result = OCCTShapeDraft(
                    handle,
                    buffer.baseAddress,
                    Int32(indices.count),
                    direction.x, direction.y, direction.z,
                    angle,
                    neutralPlane.point.x, neutralPlane.point.y, neutralPlane.point.z,
                    neutralPlane.normal.x, neutralPlane.normal.y, neutralPlane.normal.z
                )
            else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Defeaturing

    /// Remove features by deleting faces.
    ///
    /// The defeaturing algorithm removes specified faces and heals the resulting
    /// gaps by extending adjacent faces. Useful for simplifying geometry for
    /// analysis or removing small features.
    ///
    /// `defeature(faces:)` is the same operation addressing its faces as shapes rather than by
    /// index; both run one shared `BRepAlgoAPI_Defeaturing` path in the bridge, and since #578 both
    /// apply the same rule to a face this shape does not have, the whole call fails.
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let filleted = box.filleted(radius: 2.0)!
    ///
    /// // Faces past the box's own six were added by the fillet.
    /// let filletFaces = Array(filleted.faces().dropFirst(6).prefix(1))
    /// if let plain = filleted.withoutFeatures(faces: filletFaces) {
    ///     print(plain.volume ?? 0)   // back to 8000.0, the unfilleted box
    /// }
    /// ```
    ///
    /// - Parameter faces: Faces to remove (must have valid indices from this shape)
    /// - Returns: Shape with features removed, or nil on failure, including when a face's index
    ///   does not belong to this shape. Such an index used to be skipped, which returned a shape
    ///   that still carried the feature and looked no different from a successful removal (#497).
    public func withoutFeatures(faces: [Face]) -> Shape? {
        guard !faces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(faces.count)
        for face in faces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard
                let result = OCCTShapeRemoveFeatures(
                    handle, buffer.baseAddress, Int32(indices.count))
            else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Advanced Pipe Sweep

    /// Create a pipe (sweep) with advanced sweep modes.
    ///
    /// Unlike the basic `pipe(profile:path:)`, this method controls how the profile is
    /// oriented along the sweep path, what happens at corners in the spine, and whether the
    /// profile is repositioned onto the spine before sweeping.
    ///
    /// This is the single-profile form of
    /// ``pipeShellMultiSection(spine:profiles:mode:transition:withContact:withCorrection:solid:)``
    /// and runs the same code: one `BRepOffsetAPI_MakePipeShell` with one section added (#503).
    ///
    /// ```swift
    /// let spine = Wire.bspline([SIMD3(0, 0, 0), SIMD3(10, 5, 0),
    ///                           SIMD3(20, -5, 10), SIMD3(30, 0, 10)])!
    /// let profile = Wire.rectangle(width: 5, height: 3)!
    ///
    /// // Frenet lets the section roll with the spine's torsion.
    /// let rolled = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet)
    ///
    /// // A fixed binormal keeps it upright instead, which is a different solid.
    /// let upright = Shape.pipeShell(spine: spine, profile: profile,
    ///                               mode: .fixed(binormal: SIMD3(0, 0, 1)))
    /// print(rolled?.volume ?? 0)    // 177.35
    /// print(upright?.volume ?? 0)   // 150.00
    /// ```
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep
    ///   - profile: Profile wire to sweep
    ///   - mode: Sweep mode controlling profile orientation. A mode whose own argument is
    ///     unusable (`.fixed(binormal:)` given a zero-length vector, or `.auxiliary(spine:)`
    ///     given a spine OCCT rejects) returns nil rather than quietly sweeping some other
    ///     mode, which is what the pre-#503 bridge did.
    ///   - transition: How to handle transitions at spine corners
    ///   - withContact: If true, the profile is moved to touch the spine before sweeping
    ///   - withCorrection: If true, the profile is rotated to stay orthogonal to the spine
    ///   - solid: If true, create a solid; if false, create a shell
    /// - Returns: Swept shape, or nil on failure
    public static func pipeShell(
        spine: Wire,
        profile: Wire,
        mode: PipeSweepMode = .frenet,
        transition: PipeTransitionMode = .transformed,
        withContact: Bool = false,
        withCorrection: Bool = false,
        solid: Bool = true
    ) -> Shape? {
        pipeShellMultiSection(
            spine: spine, profiles: [profile], mode: mode, transition: transition,
            withContact: withContact, withCorrection: withCorrection, solid: solid)
    }

    // MARK: - Variable-Section Sweep (v0.21.0)

    /// Create a pipe shell with a law function controlling cross-section scaling.
    ///
    /// The law function defines how the profile scales along the spine.
    /// A law value of 1.0 means no scaling; 2.0 means double size, etc.
    public static func pipeShellWithLaw(
        spine: Wire,
        profile: Wire,
        law: LawFunction,
        solid: Bool = true
    ) -> Shape? {
        guard
            let result = OCCTShapeCreatePipeShellWithLaw(
                spine.handle, profile.handle, law.handle, solid)
        else { return nil }
        return Shape(handle: result)
    }

    /// Sweep one or more profiles along a spine for a variable-section pipe shell.
    ///
    /// Every `MakePipeShell` sweep in OCCTSwift is this call. Each profile is positioned in
    /// 3D at its station along the spine, and OCCT interpolates a solid (or shell) that
    /// passes through every section. It supports every orientation mode, including
    /// ``PipeSweepMode/auxiliary(spine:)``, which keeps the section oriented by a secondary
    /// curve (e.g. a thread rib that ramps from a runout to full crest along a helix while
    /// staying radial to the axis). ``pipeShell(spine:profile:mode:transition:withContact:withCorrection:solid:)``
    /// is this function with one profile (#503).
    ///
    /// ```swift
    /// let spine = Wire.line(from: .zero, to: SIMD3(0, 0, 10))!
    /// // Three coaxial circles: wide, narrow, wide. A vase.
    /// let stations = [(0.0, 2.0), (5.0, 1.0), (10.0, 2.0)].compactMap {
    ///     Wire.circle(origin: SIMD3(0, 0, $0.0), normal: SIMD3(0, 0, 1), radius: $0.1)
    /// }
    /// let vase = Shape.pipeShellMultiSection(spine: spine, profiles: stations, mode: .frenet)
    /// print(vase?.volume ?? 0)   // 58.64
    /// ```
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep.
    ///   - profiles: Profile wires, each positioned at its station along the spine. At least
    ///     one is required; two or more give a genuinely varying section.
    ///   - mode: Sweep mode controlling profile orientation (incl. `.auxiliary(spine:)`).
    ///     A mode whose own argument is unusable returns nil rather than substituting
    ///     another mode.
    ///   - transition: How to handle transitions at spine corners. Reaches a multi-section
    ///     sweep since #503; before that only the single-profile spelling could set it.
    ///   - withContact: If true, each profile is moved to touch the spine before sweeping.
    ///   - withCorrection: If true, each profile is rotated to stay orthogonal to the spine.
    ///   - solid: If true, create a solid; if false, a shell.
    /// - Returns: Swept shape, or nil on failure.
    public static func pipeShellMultiSection(
        spine: Wire,
        profiles: [Wire],
        mode: PipeSweepMode = .frenet,
        transition: PipeTransitionMode = .transformed,
        withContact: Bool = false,
        withCorrection: Bool = false,
        solid: Bool = true
    ) -> Shape? {
        guard !profiles.isEmpty else { return nil }

        let modeValue: OCCTPipeMode
        var binormal = SIMD3<Double>(0, 0, 0)
        var auxHandle: OCCTWireRef? = nil
        switch mode {
        case .frenet:
            modeValue = OCCTPipeModeFrenet
        case .correctedFrenet:
            modeValue = OCCTPipeModeCorrectedFrenet
        case .fixed(let bn):
            modeValue = OCCTPipeModeFixedBinormal
            binormal = bn
        case .auxiliary(let aux):
            modeValue = OCCTPipeModeAuxiliary
            auxHandle = aux.handle
        }

        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        guard
            let result = handles.withUnsafeBufferPointer({ buffer in
                OCCTShapeCreatePipeShellMultiSection(
                    spine.handle, buffer.baseAddress, Int32(profiles.count),
                    modeValue, binormal.x, binormal.y, binormal.z,
                    auxHandle, transition.rawValue, withContact, withCorrection, solid)
            })
        else { return nil }
        return Shape(handle: result)
    }

    /// Sweep one or more profiles along a helix to build a worm/screw-thread helicoid,
    /// keeping the section *approximately* radial via an auxiliary-spine framing on the axis.
    ///
    /// This is the turnkey form of the #180 sweep for the common helical case. It builds
    /// the helix spine and a correctly-spanning axis auxiliary spine internally, with the
    /// orientation flags (`CurvilinearEquivalence = false`, no contact) that keep the swept
    /// section roughly radial, avoiding the two footguns that make a hand-rolled
    /// `pipeShell(mode: .auxiliary(...))` return nil:
    /// 1. `Wire.helix(clockwise:)` runs the helix toward +axis or −axis depending on
    ///    handedness, so a guessed axis range can miss it entirely; and
    /// 2. the auxiliary spine must span the helix's **full** axial extent or the section
    ///    planes never intersect it.
    ///
    /// - Important: The auxiliary-spine framing is **not exactly radial**, the result bulges
    ///   ~10–15% beyond the nominal radius for moderate profiles, and for **narrow / fine-pitch
    ///   profiles (e.g. ISO thread V-forms) it balloons severely (≈2× radius) and is unusable**.
    ///   Use this for coarse worm/auger-style ribs, not precise fastener threads. A future
    ///   analytic-helicoid path will give an exact thread flank, see the thread-helicoid
    ///   tracking issue. (This is why `threadedShaft`/`threadedHole` do **not** use it.)
    ///
    /// - Warning: This builds a **standalone** helicoid. Do **not** try to make a thread by
    ///   booleaning the result with a coaxial cylinder whose surface is coincident with the
    ///   helicoid's inner/outer edge: `union` comes out BRepCheck-invalid and `subtracting`
    ///   collapses to zero volume. OCCT's BOP cannot resolve the tangent/coincident faces, and
    ///   no fuzzy value or heal pass recovers it (OCCTSwift #225, #213, #181). To build a smooth,
    ///   valid worm/screw from a custom radial cross-section, use
    ///   ``threadedRod(customProfile:nominalDiameter:pitch:cutDepth:length:axisOrigin:axisDirection:leftHanded:)``,
    ///   which composes the helicoid with the core **directly, with no boolean**.
    ///
    /// Profiles are positioned at their stations on the helix, in the (radial, axis) plane.
    /// One profile gives a uniform thread; two or more give a varying section (e.g. a
    /// runout that ramps from full crest to a small rib, the original #180 motivation).
    ///
    /// - Parameters:
    ///   - profiles: Rib profile wires positioned along the helix (at least one).
    ///   - axisOrigin: A point on the worm axis (the helix base).
    ///   - axisDirection: The worm axis direction.
    ///   - radius: Helix (pitch) radius.
    ///   - pitch: Axial advance per turn.
    ///   - turns: Number of turns.
    ///   - clockwise: Helix handedness.
    ///   - solid: If true, create a solid; if false, a shell.
    /// - Returns: The swept helicoid, or nil on failure.
    public static func helicalSweep(
        profiles: [Wire],
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        radius: Double,
        pitch: Double,
        turns: Double,
        clockwise: Bool = false,
        solid: Bool = true
    ) -> Shape? {
        guard !profiles.isEmpty, radius > 0, pitch > 0, turns > 0 else { return nil }
        let axis = simd_normalize(axisDirection)
        guard
            let helix = Wire.helix(
                origin: axisOrigin, axis: axis, radius: radius,
                pitch: pitch, turns: turns, clockwise: clockwise)
        else {
            return nil
        }
        // Auxiliary spine = the central axis, spanning the helix's full axial extent in
        // BOTH directions (the helix runs +axis or −axis depending on handedness), so every
        // section plane intersects it. A short/one-sided aux line is the usual cause of a
        // nil auxiliary-spine sweep (#185).
        let span = pitch * turns + max(pitch, radius)
        guard
            let aux = Wire.line(
                from: axisOrigin - span * axis,
                to: axisOrigin + span * axis)
        else { return nil }
        return pipeShellMultiSection(
            spine: helix, profiles: profiles,
            mode: .auxiliary(spine: aux), solid: solid)
    }

    /// Single-profile helical sweep, a uniform worm/screw-thread helicoid.
    ///
    /// See ``helicalSweep(profiles:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)``.
    public static func helicalSweep(
        profile: Wire,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        radius: Double,
        pitch: Double,
        turns: Double,
        clockwise: Bool = false,
        solid: Bool = true
    ) -> Shape? {
        helicalSweep(
            profiles: [profile], axisOrigin: axisOrigin, axisDirection: axisDirection,
            radius: radius, pitch: pitch, turns: turns, clockwise: clockwise, solid: solid)
    }

    /// Create a ruled surface between two wires.
    ///
    /// A ruled surface is created by connecting corresponding points on two
    /// boundary curves with straight lines. The result is a smooth surface
    /// that linearly interpolates between the two profiles.
    ///
    /// - Parameters:
    ///   - profile1: First boundary wire
    ///   - profile2: Second boundary wire
    /// - Returns: A shell shape containing the ruled surface, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a cone-like surface between two circles
    /// let bottom = Wire.circle(radius: 10)!
    /// let top = Wire.circle(radius: 5)!.offset3D(distance: 20, direction: SIMD3(0, 0, 1))!
    /// let cone = Shape.ruled(profile1: bottom, profile2: top)
    /// ```
    public static func ruled(profile1: Wire, profile2: Wire) -> Shape? {
        guard let result = OCCTShapeCreateRuled(profile1.handle, profile2.handle) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Create a shell (hollow solid) with specific faces left open.
    ///
    /// Unlike the basic `shelled(thickness:)` method, this allows you to specify
    /// which faces should be removed to create openings.
    ///
    /// - Note: Every face must be one of *this* shape's, by index. A `Face` whose `index` names no
    ///   face here fails the whole call rather than being skipped (#568). Previously such a face
    ///   was dropped and the solid was shelled with fewer openings than asked for.
    ///
    /// - Parameters:
    ///   - thickness: Wall thickness (positive = inward, negative = outward)
    ///   - openFaces: Faces to leave open (must have valid indices from this shape)
    /// - Returns: Shelled shape with specified faces open, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a box with an open top
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let topFaces = box.upwardFaces()
    /// let openBox = box.shelled(thickness: 2.0, openFaces: topFaces)
    /// ```
    public func shelled(thickness: Double, openFaces: [Face]) -> Shape? {
        guard !openFaces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(openFaces.count)
        for face in openFaces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard
                let result = OCCTShapeShellWithOpenFaces(
                    handle,
                    thickness,
                    buffer.baseAddress,
                    Int32(indices.count)
                )
            else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// Remove faces smaller than the specified area threshold.
    ///
    /// Useful for cleaning up shapes with very small faces that can cause
    /// problems in downstream operations.
    ///
    /// - Parameter minArea: Minimum area threshold; faces smaller than this are removed
    /// - Returns: Cleaned shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Remove faces smaller than 0.01 mm²
    /// let cleaned = shape.withoutSmallFaces(minArea: 0.01)
    /// ```
    public func withoutSmallFaces(minArea: Double) -> Shape? {
        guard let result = OCCTShapeRemoveSmallFaces(handle, minArea) else {
            return nil
        }
        return Shape(handle: result)
    }
    // MARK: - Variable Radius Fillet (v0.14.0)

    /// Apply a variable radius fillet to a specific edge.
    ///
    /// The radius varies along the edge according to the given radius/parameter pairs.
    /// Parameters are normalized from 0.0 (start of edge) to 1.0 (end of edge).
    ///
    /// Every radius must be positive, the parameters must lie in `0...1` and strictly increase, and
    /// `edgeIndex` must name an edge of this shape; otherwise the call returns `nil`.
    ///
    /// - Parameters:
    ///   - edgeIndex: 0-based index of the edge to fillet, as reported by ``Edge/index``
    ///   - radiusProfile: Array of (parameter, radius) pairs defining the radius along the edge;
    ///     at least two
    /// - Returns: Filleted shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fillet with radius varying from 1mm at start to 3mm at end
    /// let filleted = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
    /// )
    ///
    /// // Fillet with radius varying: 1mm at start, 2mm at middle, 1mm at end
    /// let complexFillet = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(0.0, 1.0), (0.5, 2.0), (1.0, 1.0)]
    /// )
    ///
    /// // Rejected: a descending parameter would silently reverse the law
    /// let invalid = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(1.0, 1.0), (0.0, 3.0)]
    /// )  // nil
    /// ```
    ///
    /// > Note: OCCT stretches the profile across the whole edge, so it cannot fillet part of one
    /// > and leave the rest alone. With exactly two points the parameters are ignored and only the
    /// > endpoint radii are used; with three or more only the *relative* spacing of the interior
    /// > points survives, because OCCT renormalises the first parameter to 0 and the last to 1.
    public func filletedVariable(
        edgeIndex: Int,
        radiusProfile: [(parameter: Double, radius: Double)]
    ) -> Shape? {
        guard radiusProfile.count >= 2 else { return nil }

        var radii = radiusProfile.map { $0.radius }
        var params = radiusProfile.map { $0.parameter }

        guard
            let result = OCCTShapeFilletVariable(
                handle,
                Int32(edgeIndex),
                &radii,
                &params,
                Int32(radii.count)
            )
        else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Multi-Edge Blend (v0.14.0)

    /// Apply fillets to multiple edges with individual radii.
    ///
    /// Each edge can have its own fillet radius, allowing for more control
    /// than applying a uniform fillet to all edges.
    ///
    /// Every radius must be positive: one non-positive (or NaN) radius rejects the whole batch,
    /// the same contract ``filleted(edges:radius:)`` and
    /// ``filleted(edges:startRadius:endRadius:)`` apply to theirs. Every index must name an edge of
    /// this shape, on the same all-or-nothing basis: one that does not rejects the batch rather
    /// than being skipped, so a result is never a partial fillet reported as a complete one.
    ///
    /// The same edge index named twice is **not** rejected and does not combine the two radii: OCCT
    /// writes both `Add` calls to that edge's own slot within its fillet contour, so the *second*
    /// silently overwrites the first (#633). This is unchanged, existing behaviour, documented here
    /// because it used to be undocumented and silent; use ``blendedEdgesWithReport(_:)`` for the
    /// same fillet with a report naming which entries a duplicate overwrote.
    ///
    /// - Parameter edgeRadii: Array of (0-based edgeIndex, radius) pairs; each radius must be > 0
    /// - Returns: Filleted shape, or nil on failure, including an empty array, a non-positive
    ///   radius anywhere in the array, or an index that names no edge of this shape
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Apply different radii to different edges
    /// let blended = shape.blendedEdges([
    ///     (0, 1.0),  // Edge 0 gets 1mm fillet
    ///     (1, 2.0),  // Edge 1 gets 2mm fillet
    ///     (2, 0.5)   // Edge 2 gets 0.5mm fillet
    /// ])
    ///
    /// // Rejected: a radius of zero is not a fillet, so the batch returns nil
    /// let invalid = shape.blendedEdges([(0, 1.0), (1, 0.0)])  // nil
    ///
    /// // Rejected: 99_999 names no edge, so the batch returns nil rather than filleting edge 0
    /// let outOfRange = shape.blendedEdges([(0, 1.0), (99_999, 2.0)])  // nil
    /// ```
    public func blendedEdges(_ edgeRadii: [(edgeIndex: Int, radius: Double)]) -> Shape? {
        guard !edgeRadii.isEmpty, edgeRadii.allSatisfy({ $0.radius > 0 }) else { return nil }

        var indices = edgeRadii.map { Int32($0.edgeIndex) }
        var radii = edgeRadii.map { $0.radius }

        guard
            let result = OCCTShapeBlendEdges(
                handle,
                &indices,
                &radii,
                Int32(edgeRadii.count),
                nil,
                nil
            )
        else {
            return nil
        }
        return Shape(handle: result)
    }

    /// ``blendedEdges(_:)``, also reporting which requested edges OCCT declined to fillet, and
    /// which duplicate entries were silently overwritten (#633).
    ///
    /// `blendedEdges(_:)` does not deduplicate `edgeRadii`: naming the same edge index twice writes
    /// the same fillet slot twice, and only the *last* radius written survives -- the earlier one is
    /// discarded with no signal, the same shape of silent-wrong-answer #639 found on the declined-edge
    /// axis of this family. That existing behaviour is unchanged here; this method only adds a way
    /// to observe it, following #639's recommendation to extend ``FilletResult`` rather than invent
    /// a second reporting shape for the same idea.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// if let report = box.blendedEdgesWithReport([(0, 2.0), (0, 5.0)]) {
    ///     print(report.overwrittenDuplicateIndices)   // [0]: edge 0's first radius (2.0) lost
    ///     print(report.declinedEdgeIndices)            // []: every edge of a closed box fillets
    /// }
    /// ```
    ///
    /// - Parameter edgeRadii: Array of (0-based edgeIndex, radius) pairs; each radius must be > 0
    /// - Returns: A ``FilletResult``, or nil on failure under the same conditions as
    ///   ``blendedEdges(_:)``.
    public func blendedEdgesWithReport(_ edgeRadii: [(edgeIndex: Int, radius: Double)])
        -> FilletResult?
    {
        guard !edgeRadii.isEmpty, edgeRadii.allSatisfy({ $0.radius > 0 }) else { return nil }

        var indices = edgeRadii.map { Int32($0.edgeIndex) }
        var radii = edgeRadii.map { $0.radius }

        var declined = [Int32](repeating: 0, count: edgeRadii.count)
        var declinedCount: Int32 = 0
        let result: OCCTShapeRef? = declined.withUnsafeMutableBufferPointer { declinedBuffer in
            OCCTShapeBlendEdges(
                handle,
                &indices,
                &radii,
                Int32(edgeRadii.count),
                declinedBuffer.baseAddress,
                &declinedCount
            )
        }
        guard let result else { return nil }
        let declinedIndices = declined.prefix(Int(declinedCount)).map { Int($0) }
        return FilletResult(
            shape: Shape(handle: result), declinedEdgeIndices: declinedIndices,
            overwrittenDuplicateIndices: Shape.overwrittenDuplicateIndices(in: edgeRadii))
    }

    /// 0-based edge indices from `edgeRadii` that a later entry in the same request overwrote.
    ///
    /// This is a property of `edgeRadii` itself: `edgeIndex` maps to a unique edge via `Shape`'s own
    /// `TopExp` enumeration, so two entries naming the same numeric index always name the same edge,
    /// and no OCCT round trip is needed to tell which entries lost. Mirrors ``FilletResult`` /
    /// `declinedEdgeIndices`'s own convention: every overwritten *entry* is reported, not just the
    /// distinct edges, so `[(0, 1.0), (0, 2.0), (0, 3.0)]` reports `[0, 0]` -- two entries lost, one
    /// (the last) won -- not `[0]`.
    private static func overwrittenDuplicateIndices(
        in edgeRadii: [(edgeIndex: Int, radius: Double)]
    ) -> [Int] {
        var lastPosition: [Int: Int] = [:]
        for (position, pair) in edgeRadii.enumerated() {
            lastPosition[pair.edgeIndex] = position
        }
        var overwritten: [Int] = []
        for (position, pair) in edgeRadii.enumerated()
        where lastPosition[pair.edgeIndex] != position {
            overwritten.append(pair.edgeIndex)
        }
        return overwritten
    }

    /// Create a wedge (tapered box).
    ///
    /// A wedge is a box whose top face is narrowed in the X direction.
    /// When `ltx` equals `dx`, the result is a regular box.
    /// When `ltx` is 0, the result is a pyramid.
    ///
    /// - Parameters:
    ///   - dx: Width in X
    ///   - dy: Height in Y
    ///   - dz: Depth in Z
    ///   - ltx: Width of top face in X (0 to dx)
    /// - Returns: A wedge solid, or nil on failure
    public static func wedge(dx: Double, dy: Double, dz: Double, ltx: Double) -> Shape? {
        guard dx > 0, dy > 0, dz > 0, ltx >= 0 else { return nil }
        guard let h = OCCTShapeCreateWedge(dx, dy, dz, ltx) else { return nil }
        return Shape(handle: h)
    }

    /// Create an advanced wedge with custom top face bounds.
    ///
    /// - Parameters:
    ///   - dx: Width in X
    ///   - dy: Height in Y
    ///   - dz: Depth in Z
    ///   - xmin: Minimum X of the face at `dy`
    ///   - zmin: Minimum Z of the face at `dy`
    ///   - xmax: Maximum X of the face at `dy`
    ///   - zmax: Maximum Z of the face at `dy`
    /// - Returns: A wedge solid, or nil on failure
    public static func wedge(
        dx: Double, dy: Double, dz: Double,
        xmin: Double, zmin: Double,
        xmax: Double, zmax: Double
    ) -> Shape? {
        guard dx > 0, dy > 0, dz > 0 else { return nil }
        guard let h = OCCTShapeCreateWedgeAdvanced(dx, dy, dz, xmin, zmin, xmax, zmax)
        else { return nil }
        return Shape(handle: h)
    }
    /// Create an oriented wedge at an arbitrary origin along an arbitrary direction.
    ///
    /// - Parameters:
    ///   - origin: Corner point of the wedge.
    ///   - direction: Axis direction for the wedge height (will be normalized).
    ///   - dx: Width in X (local frame).
    ///   - dy: Height in Y (local frame).
    ///   - dz: Depth in Z (local frame).
    ///   - ltx: Width of top face in X (0 to dx).
    /// - Returns: A wedge solid, or nil on failure.
    public static func wedge(
        at origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        dx: Double, dy: Double, dz: Double,
        ltx: Double
    ) -> Shape? {
        guard
            let h = OCCTShapeCreateWedgeOriented(
                origin.x, origin.y, origin.z,
                direction.x, direction.y, direction.z,
                dx, dy, dz, ltx
            )
        else { return nil }
        return Shape(handle: h)
    }
    /// Create a half-space solid from a face.
    ///
    /// A half-space is an infinite solid on one side of a face.
    /// The reference point indicates which side is solid.
    ///
    /// - Note: Only the **first** face of `face` is used. A shape holding several faces
    ///   produces a half-space bounded by one of them, not by all of them; pass the single
    ///   dividing face to be explicit about which.
    ///
    /// - Parameters:
    ///   - face: A shape containing the dividing face
    ///   - referencePoint: A point on the solid side
    /// - Returns: A half-space solid, or nil on failure
    public static func halfSpace(face: Shape, referencePoint: SIMD3<Double>) -> Shape? {
        guard
            let h = OCCTShapeCreateHalfSpace(
                face.handle,
                referencePoint.x, referencePoint.y, referencePoint.z)
        else { return nil }
        return Shape(handle: h)
    }
    /// Create a draft shell by sweeping this shape along a direction with taper angle.
    ///
    /// - Parameters:
    ///   - direction: Draft direction
    ///   - angle: Taper angle in radians
    ///   - length: Maximum draft length
    /// - Returns: A draft shell shape, or nil on failure
    public func draft(direction: SIMD3<Double>, angle: Double, length: Double) -> Shape? {
        guard
            let h = OCCTShapeMakeDraft(
                handle,
                direction.x, direction.y, direction.z,
                angle, length)
        else { return nil }
        return Shape(handle: h)
    }
    /// Create a simple surface-level offset of this shape.
    ///
    /// Moves each face by a constant distance without filleting intersections.
    /// Faster than `offset(by:)` for thin-wall operations.
    ///
    /// - Parameter distance: Offset distance (positive = outward)
    /// - Returns: The offset shape, or nil on failure
    public func simpleOffset(by distance: Double) -> Shape? {
        guard let h = OCCTShapeSimpleOffset(handle, distance) else { return nil }
        return Shape(handle: h)
    }
    /// Extract the middle (spine) path from a pipe-like shape.
    ///
    /// Given two end faces/wires of a pipe-like shape, computes the
    /// spine wire running through the middle. Useful for reverse-engineering
    /// sweep operations from imported geometry.
    ///
    /// - Parameters:
    ///   - startShape: One end of the pipe (face or wire)
    ///   - endShape: Other end of the pipe (face or wire)
    /// - Returns: The middle path wire, or nil on failure
    public func middlePath(start startShape: Shape, end endShape: Shape) -> Shape? {
        guard let h = OCCTShapeMiddlePath(handle, startShape.handle, endShape.handle) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Connect separate shapes by making them share common geometry.
    ///
    /// Makes shapes share geometry at coincident boundaries.
    /// Useful for finite element mesh preparation.
    ///
    /// - Parameter shapes: Array of shapes to connect
    /// - Returns: Connected shape, or nil on failure
    public static func makeConnected(_ shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeMakeConnected(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
    /// Add a linear rib feature to a shape.
    ///
    /// Creates a rib (reinforcement) or slot by extruding a wire profile
    /// in the given direction on the base shape.
    ///
    /// - Parameters:
    ///   - profile: The wire profile of the rib
    ///   - direction: Extrusion direction of the rib
    ///   - draftDirection: Secondary direction controlling draft angle
    ///   - fuse: true to add material (rib), false to remove material (slot)
    /// - Returns: Shape with rib/slot added, or nil on failure
    public func addingLinearRib(
        profile: Wire,
        direction: SIMD3<Double>,
        draftDirection: SIMD3<Double>,
        fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapeAddLinearRib(
                handle, profile.handle,
                direction.x, direction.y, direction.z,
                draftDirection.x, draftDirection.y, draftDirection.z,
                fuse)
        else { return nil }
        return Shape(handle: h)
    }
    /// Add a draft prism (tapered extrusion) to a shape.
    ///
    /// Creates a boss or pocket with draft angle (taper), commonly used
    /// in injection mold design.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - draftAngle: Draft angle in degrees
    ///   - height: Extrusion height
    ///   - fuse: true to add material (boss), false to cut (pocket)
    /// - Returns: Shape with draft prism, or nil on failure
    public func addingDraftPrism(
        profile: Wire, sketchFaceIndex: Int,
        draftAngle: Double, height: Double,
        fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapeDraftPrism(
                handle, Int32(sketchFaceIndex),
                profile.handle, draftAngle,
                height, fuse)
        else { return nil }
        return Shape(handle: h)
    }

    /// Add a draft prism that extends through the entire shape.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - draftAngle: Draft angle in degrees
    ///   - fuse: true to add material, false to cut
    /// - Returns: Shape with draft prism, or nil on failure
    public func addingDraftPrismThruAll(
        profile: Wire, sketchFaceIndex: Int,
        draftAngle: Double,
        fuse: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTShapeDraftPrismThruAll(
                handle, Int32(sketchFaceIndex),
                profile.handle, draftAngle,
                fuse)
        else { return nil }
        return Shape(handle: h)
    }
    /// Compute the intersection curves/edges between two shapes.
    ///
    /// Returns the intersection geometry (edges/wires) where the two shapes overlap.
    /// Useful for finding contact curves, trim boundaries, and interference analysis.
    ///
    /// - Parameter other: The second shape to intersect with
    /// - Returns: Shape containing intersection edges, or nil on failure
    public func section(_ other: Shape) -> Shape? {
        guard let h = OCCTShapeSection(handle, other.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Check whether this shape is valid for boolean operations.
    ///
    /// - Returns: true if the shape is suitable for boolean operations
    public var isValidForBoolean: Bool {
        OCCTShapeBooleanCheck(handle, nil)
    }

    /// Check whether two shapes are valid for boolean operations with each other.
    ///
    /// - Parameter other: The other shape to check compatibility with
    /// - Returns: true if both shapes are suitable for boolean operations together
    public func isValidForBoolean(with other: Shape) -> Bool {
        OCCTShapeBooleanCheck(handle, other.handle)
    }
    /// Split a face by imprinting a wire onto it.
    ///
    /// The wire is projected/imprinted onto the specified face, dividing it
    /// into multiple faces. Useful for mesh preparation and feature line imprinting.
    ///
    /// - Parameters:
    ///   - wire: Wire to imprint onto the face
    ///   - faceIndex: 0-based index of the face to split
    /// - Returns: Shape with the face split by the wire, or nil on failure
    public func splittingFace(with wire: Wire, faceIndex: Int) -> Shape? {
        guard let h = OCCTShapeSplitByWire(handle, wire.handle, Int32(faceIndex)) else {
            return nil
        }
        return Shape(handle: h)
    }
    /// Split surfaces that span more than a specified angle.
    ///
    /// Useful for export to systems that cannot handle full 360° surfaces
    /// (e.g., splitting a full cylinder into quarter-cylinders with maxAngle=90).
    ///
    /// - Parameter maxAngleDegrees: Maximum angle in degrees (e.g., 90 for quarter-turns)
    /// - Returns: Shape with surfaces split at angle boundaries, or nil on failure
    public func splitByAngle(_ maxAngleDegrees: Double) -> Shape? {
        guard let h = OCCTShapeSplitByAngle(handle, maxAngleDegrees) else { return nil }
        return Shape(handle: h)
    }
    /// Fuse multiple shapes simultaneously.
    ///
    /// More robust than sequential pairwise `union(with:)` calls, as it avoids
    /// intermediate tolerance issues and processes all intersections at once.
    ///
    /// - Parameter shapes: Array of shapes to fuse together
    /// - Returns: Fused shape, or nil on failure
    public static func fuseAll(_ shapes: [Shape]) -> Shape? {
        guard shapes.count >= 2 else { return nil }
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let result = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeFuseMulti(buffer.baseAddress, Int32(shapes.count))
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
    /// Generate multiple parallel offset wires from a planar face boundary.
    ///
    /// More efficient than calling `Wire.offset` multiple times, and produces
    /// consistent results for CNC toolpath generation.
    ///
    /// - Parameters:
    ///   - offsets: Array of offset distances (positive = outward, negative = inward)
    ///   - joinType: How to join offset segments (default: .arc)
    /// - Returns: Array of offset wires
    public func multiOffsetWires(
        offsets: [Double],
        joinType: OffsetJoinType = .arc
    ) -> [Wire] {
        guard !offsets.isEmpty else { return [] }
        let maxWires = offsets.count * 10  // Allow for multi-contour results
        var wireRefs = [OCCTWireRef?](repeating: nil, count: maxWires)
        let count = offsets.withUnsafeBufferPointer { offsetBuf in
            wireRefs.withUnsafeMutableBufferPointer { wireBuf in
                OCCTWireMultiOffset(
                    handle, offsetBuf.baseAddress, Int32(offsets.count),
                    joinType.rawValue, wireBuf.baseAddress, Int32(maxWires))
            }
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = wireRefs[i] else { return nil }
            return Wire(handle: ref)
        }
    }
    /// Fuse this shape with another and track which faces were modified.
    ///
    /// - Parameter other: Shape to fuse with
    /// - Returns: Boolean result with modified face tracking, or nil on failure
    public func fuseWithHistory(_ other: Shape) -> BooleanResult? {
        let maxModified: Int32 = 256
        var modRefs = [OCCTShapeRef?](repeating: nil, count: Int(maxModified))
        let count = modRefs.withUnsafeMutableBufferPointer { buf in
            OCCTShapeFuseWithHistory(handle, other.handle, buf.baseAddress, maxModified)
        }
        guard count >= 0 else { return nil }
        // The fuse result is the union
        guard let fused = self.union(other) else { return nil }
        let modified = (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = modRefs[i] else { return nil }
            return Shape(handle: ref)
        }
        return BooleanResult(shape: fused, modifiedFaces: modified)
    }
    /// Boolean union (`self ∪ other`) with full per-input-subshape history.
    /// - Returns: `(result, history)` on success; nil if the operation failed.
    public func unionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTBooleanUnionWithHistory(handle, other.handle, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Boolean subtract (`self \ tool`) with full per-input-subshape history.
    public func subtractedWithFullHistory(_ tool: Shape) -> (
        result: Shape, history: ShapeHistoryRef
    )? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTBooleanSubtractWithHistory(handle, tool.handle, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Boolean intersect (`self ∩ other`) with full per-input-subshape history.
    public func intersectionWithFullHistory(_ other: Shape) -> (
        result: Shape, history: ShapeHistoryRef
    )? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTBooleanIntersectWithHistory(handle, other.handle, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Split `self` by `tool` (BRepAlgoAPI_Splitter).
    ///
    /// The pieces are the top-level children of the compound result; query history per input
    /// sub-shape via `history.record(of:)`.
    public func splitWithFullHistory(by tool: Shape) -> (pieces: [Shape], history: ShapeHistoryRef)?
    {
        var compoundRef: OCCTShapeRef?
        guard let h = OCCTBooleanSplitWithHistory(handle, tool.handle, &compoundRef),
            let compoundRef
        else { return nil }
        let compound = Shape(handle: compoundRef)

        let pieceCount = OCCTShapeCompoundChildren(compound.handle, nil, 0)
        let pieces: [Shape]
        if pieceCount > 0 {
            var refs = [OCCTShapeRef?](repeating: nil, count: Int(pieceCount))
            _ = refs.withUnsafeMutableBufferPointer { buf in
                OCCTShapeCompoundChildren(compound.handle, buf.baseAddress, pieceCount)
            }
            pieces = refs.compactMap { ref in ref.map(Shape.init(handle:)) }
        } else {
            pieces = []
        }
        return (pieces, ShapeHistoryRef(h))
    }
    /// Apply a uniform-radius fillet to the given edges, returning the result
    /// shape and a `ShapeHistoryRef` queryable for `Modified` / `Generated` /
    /// `IsDeleted` per input sub-shape (e.g. a filleted edge → multiple
    /// generated fillet faces).
    ///
    /// An edge OCCT declines to fillet is skipped, exactly as ``filleted(edges:radius:)`` skips
    /// it; see ``ShapeHistoryRecord``'s own doc for how to recover which requested edges those
    /// were from the returned history (#639).
    ///
    /// `radius` must be positive, matching ``filleted(edges:radius:)``.
    public func filletedWithFullHistory(radius: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !edges.isEmpty, radius > 0 else { return nil }
        let edgeIndices = edges.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = edgeIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromFilletEdges(
                handle, buf.baseAddress!, Int32(edgeIndices.count),
                radius, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Variable-radius fillet on a single edge: radius linearly varies from
    /// `startRadius` (at the edge's first parameter) to `endRadius` (at last).
    ///
    /// Both radii must be positive, matching ``filleted(edges:startRadius:endRadius:)``.
    public func filletedWithFullHistory(edge: Int, startRadius: Double, endRadius: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard startRadius > 0, endRadius > 0 else { return nil }
        var resultRef: OCCTShapeRef?
        guard
            let h = OCCTShapeHistoryFromFilletEdgeVariable(
                handle, Int32(edge),
                startRadius, endRadius,
                &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Apply a uniform chamfer to the given edges, returning the result and
    /// a queryable history.
    ///
    /// Edge indices are 0-based positions in ``edges()``. An index naming no edge of this shape
    /// fails the whole call rather than being skipped (#568), matching
    /// ``filletedWithFullHistory(radius:edges:)``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// if let (chamfered, history) = box.chamferedWithFullHistory(distance: 1.0, edges: [0, 1]),
    ///    let edge = box.subShapes(ofType: .edge).first {
    ///     print(chamfered.volume ?? 0, history.record(of: edge).modified.count)
    /// }
    /// ```
    public func chamferedWithFullHistory(distance: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !edges.isEmpty else { return nil }
        let edgeIndices = edges.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = edgeIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromChamferEdges(
                handle, buf.baseAddress!, Int32(edgeIndices.count),
                distance, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Shell / hollow: remove the listed faces and offset the remaining shell
    /// inward by `thickness` (use a negative `thickness` for outward), with a
    /// queryable per-face history.
    public func shelledWithFullHistory(
        facesToRemove: [Int], thickness: Double, tolerance: Double = 1e-3
    )
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !facesToRemove.isEmpty else { return nil }
        let faceIndices = facesToRemove.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = faceIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromShell(
                handle, buf.baseAddress!, Int32(faceIndices.count),
                thickness, tolerance, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Defeature: remove given faces by reconnecting surrounding topology.
    ///
    /// History reports each removed face as deleted and surrounding faces as modified.
    public func defeaturedWithFullHistory(faces: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !faces.isEmpty else { return nil }
        let faceIndices = faces.map { Int32($0) }
        var resultRef: OCCTShapeRef?
        let h = faceIndices.withUnsafeBufferPointer { buf in
            OCCTShapeHistoryFromDefeature(
                handle, buf.baseAddress!, Int32(faceIndices.count),
                &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }
    /// Sew multiple shapes into a connected shell or solid, with full
    /// per-input-subshape history (vertex/edge merges, small-face removal).
    ///
    /// Where two coincident inputs merge into one shared output (the common
    /// case for sewing), both inputs show up as `modified` into that same
    /// output sub-shape, there is no ambiguity between which side "won".
    ///
    /// - Returns: `(result, history)` on success; nil on failure.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let faces = [topFace, bottomFace, frontFace, backFace, leftFace, rightFace]
    /// guard let (solid, history) = Shape.sewWithFullHistory(shapes: faces, tolerance: 1e-6) else { return }
    /// let record = history.record(of: topFace)
    /// print(record.modified, record.isDeleted)
    /// ```
    public static func sewWithFullHistory(shapes: [Shape], tolerance: Double = 1e-6)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !shapes.isEmpty else { return nil }
        var shapeHandles = shapes.map { $0.handle as OCCTShapeRef? }
        var resultRef: OCCTShapeRef?
        let h = shapeHandles.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeSewWithHistory(buffer.baseAddress, Int32(shapes.count), tolerance, &resultRef)
        }
        guard let h, let resultRef else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Sew this shape with another, with full per-input-subshape history.
    public func sewnWithFullHistory(with other: Shape, tolerance: Double = 1e-6)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        Shape.sewWithFullHistory(shapes: [self, other], tolerance: tolerance)
    }

    /// Sew disconnected faces within this shape together, with full history.
    public func sewnWithFullHistory(tolerance: Double = 1e-6)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeSewSingleWithHistory(handle, tolerance, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Quilt multiple shapes (faces/shells) into a single shell, with full
    /// per-input-subshape history.
    public static func quiltWithFullHistory(_ shapes: [Shape])
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        guard !shapes.isEmpty else { return nil }
        var handles = shapes.map { $0.handle }
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeQuiltWithHistory(&handles, Int32(shapes.count), &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Attempt to repair/heal the shape, with full per-input-subshape history.
    ///
    /// ## Example
    ///
    /// ```swift
    /// guard let (healed, history) = brokenShape.healedWithFullHistory() else { return }
    /// let record = history.record(of: someFace)
    /// ```
    public func healedWithFullHistory() -> (result: Shape, history: ShapeHistoryRef)? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeHealWithHistory(handle, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Create a solid from a closed shell, with full per-input-subshape history.
    ///
    /// History only reflects the orientation-fix pass: wrapping an already-closed shell into a
    /// solid does not itself modify any sub-shape.
    ///
    /// Body selection matches ``Shape/solid(from:)``: one solid per body-bounding shell,
    /// a compound when there is more than one, cavity shells skipped. The single history
    /// covers every body.
    ///
    /// ```swift
    /// let sewn = Shape.sew(shapes: [bodyA, bodyB], tolerance: 1e-6)!
    /// guard let (solids, history) = Shape.solidWithFullHistory(from: sewn) else { return }
    /// print(solids.solids.count)   // 2
    /// ```
    public static func solidWithFullHistory(from shell: Shape) -> (
        result: Shape, history: ShapeHistoryRef
    )? {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeCreateSolidFromShellWithHistory(shell.handle, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }
    /// Translate the shape, with full per-input-subshape history.
    ///
    /// ## Example
    ///
    /// ```swift
    /// guard let (moved, history) = body.translatedWithFullHistory(by: SIMD3(10, 0, 0)) else { return }
    /// let record = history.record(of: someFace)
    /// ```
    public func translatedWithFullHistory(by offset: SIMD3<Double>)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard
            let h = OCCTShapeHistoryFromTranslate(handle, offset.x, offset.y, offset.z, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Rotate around an axis through the origin, with full per-input-subshape history.
    public func rotatedWithFullHistory(axis: SIMD3<Double>, angle: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeHistoryFromRotate(handle, axis.x, axis.y, axis.z, angle, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Scale uniformly from the origin, with full per-input-subshape history.
    public func scaledWithFullHistory(by factor: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard let h = OCCTShapeHistoryFromScale(handle, factor, &resultRef),
            let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Mirror across a plane, with full per-input-subshape history.
    public func mirroredWithFullHistory(
        planeNormal: SIMD3<Double>, planeOrigin: SIMD3<Double> = .zero
    )
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard
            let h = OCCTShapeHistoryFromMirror(
                handle,
                planeOrigin.x, planeOrigin.y, planeOrigin.z,
                planeNormal.x, planeNormal.y, planeNormal.z,
                &resultRef
            ), let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Create a linear pattern of the shape, with full history.
    ///
    /// The pattern is N:1 (deterministic): each instance's sub-shapes
    /// correspond to the source's by construction, so a source sub-shape's
    /// `history.record(of:).modified` reports all `count` corresponding
    /// instance sub-shapes, one per copy, including the original at index 0.
    ///
    /// - Returns: `(result, history)` where `result` is a compound of all
    ///   copies, same as ``linearPattern(direction:spacing:count:)``.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10)
    /// guard let (row, history) = hole.linearPatternWithFullHistory(
    ///     direction: SIMD3(20, 0, 0), spacing: 20, count: 5
    /// ) else { return }
    /// let copies = history.record(of: someHoleFace).modified // 5 corresponding faces
    /// ```
    public func linearPatternWithFullHistory(direction: SIMD3<Double>, spacing: Double, count: Int)
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard
            let h = OCCTShapeHistoryFromLinearPattern(
                handle, direction.x, direction.y, direction.z, spacing, Int32(count), &resultRef
            ), let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }

    /// Create a circular pattern of the shape, with full history.
    ///
    /// Same N:1 semantics as ``linearPatternWithFullHistory(direction:spacing:count:)``
    ///, see ``circularPattern(axisPoint:axisDirection:count:angle:)`` for what
    /// "duplicates the whole body" means for feature-cut use cases.
    ///
    /// - Returns: `(result, history)` where `result` is a compound of all copies.
    public func circularPatternWithFullHistory(
        axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>,
        count: Int, angle: Double = 0
    )
        -> (result: Shape, history: ShapeHistoryRef)?
    {
        var resultRef: OCCTShapeRef?
        guard
            let h = OCCTShapeHistoryFromCircularPattern(
                handle,
                axisPoint.x, axisPoint.y, axisPoint.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                Int32(count), angle, &resultRef
            ), let resultRef
        else { return nil }
        return (Shape(handle: resultRef), ShapeHistoryRef(h))
    }
    /// Create a hollowed (thick) solid by removing faces and offsetting inward.
    ///
    /// Removes the specified faces and creates a shell with uniform wall thickness.
    /// The removed faces become openings in the resulting hollow shape.
    ///
    /// - Parameters:
    ///   - faceIndices: 0-based indices of faces to remove (become openings)
    ///   - thickness: Wall thickness (positive = offset inward)
    ///   - tolerance: Tolerance for the operation
    ///   - joinType: How to join offset edges (default: .arc)
    /// - Returns: Hollowed solid, or nil on failure
    public func hollowed(
        removingFaces faceIndices: [Int],
        thickness: Double,
        tolerance: Double = 1e-3,
        joinType: OffsetJoinType = .arc
    ) -> Shape? {
        guard !faceIndices.isEmpty else { return nil }
        let indices = faceIndices.map { Int32($0) }
        let result = indices.withUnsafeBufferPointer { buf in
            OCCTShapeMakeThickSolid(
                handle, buf.baseAddress, Int32(faceIndices.count),
                thickness, tolerance, joinType.rawValue)
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
    /// Compute the common (intersection) of multiple shapes simultaneously.
    ///
    /// - Parameter shapes: Array of shapes to intersect
    /// - Returns: Common shape (intersection of all), or nil on failure
    public static func commonAll(_ shapes: [Shape]) -> Shape? {
        guard shapes.count >= 2 else { return nil }
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let result = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeCommonMulti(buffer.baseAddress, Int32(shapes.count))
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
    /// Fuse with another shape and fillet the intersection edges.
    ///
    /// - Parameters:
    ///   - other: Shape to fuse with.
    ///   - radius: Fillet radius for intersection edges.
    /// - Returns: Fused and filleted shape, or nil on failure.
    public func fusedAndBlended(with other: Shape, radius: Double) -> Shape? {
        guard let h = OCCTShapeFuseAndBlend(handle, other.handle, radius) else { return nil }
        return Shape(handle: h)
    }

    /// Cut another shape and fillet the intersection edges.
    ///
    /// - Parameters:
    ///   - other: Shape to cut from this shape.
    ///   - radius: Fillet radius for intersection edges.
    /// - Returns: Cut and filleted shape, or nil on failure.
    public func cutAndBlended(with other: Shape, radius: Double) -> Shape? {
        guard let h = OCCTShapeCutAndBlend(handle, other.handle, radius) else { return nil }
        return Shape(handle: h)
    }
    /// Apply evolving-radius fillets to multiple edges simultaneously.
    ///
    /// The request is rejected as a whole, rather than partly applied, whenever it is malformed: an
    /// `edgeIndex` naming no edge of this shape returns `nil` rather than filleting the rest, and so
    /// does any radius that is not positive, any parameter outside `0...1`, any non-increasing
    /// parameter sequence, and an empty `radiusPoints`.
    ///
    /// Each edge's law is applied to that edge's own position within its own contour, so
    /// tangent-continuous edges, the sides and ends of a rounded slot's rim, say, can each carry a
    /// different law even though OCCT groups them into a single contour.
    ///
    /// Separately from a malformed request, OCCT itself declines to fillet some edges outright (a
    /// free-boundary edge of an open shell). Those are skipped, exactly as ``Shape/blendedEdges(_:)``
    /// and ``Shape/filleted(edges:radius:)`` skip them; if OCCT declines *every* edge of the
    /// request, the call returns `nil` rather than the unfilleted input. (#612)
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let edges = box.edges()
    /// let filleted = box.filletEvolving([
    ///     EvolvingFilletEdge(edge: edges[0], radiusPoints: [(0.0, 1.0), (1.0, 3.0)]),
    ///     EvolvingFilletEdge(edge: edges[2], radiusPoints: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)]),
    /// ])
    ///
    /// // A rounded slot: two straight sides joined by two semicircular ends, extruded. Its whole
    /// // top rim is one tangent-continuous contour, and each edge of it still carries its own law.
    /// let profile = Wire.join([
    ///     Wire.line(from: SIMD3(-10, -8, 0), to: SIMD3(10, -8, 0))!,
    ///     Wire.arc(start: SIMD3(10, -8, 0), midpoint: SIMD3(18, 0, 0), end: SIMD3(10, 8, 0))!,
    ///     Wire.line(from: SIMD3(10, 8, 0), to: SIMD3(-10, 8, 0))!,
    ///     Wire.arc(start: SIMD3(-10, 8, 0), midpoint: SIMD3(-18, 0, 0), end: SIMD3(-10, -8, 0))!,
    /// ])!
    /// let slot = Shape.face(from: profile)!.extruded(by: SIMD3(0, 0, 20))!
    /// let rim = slot.edges()
    /// let tapered = slot.filletEvolving([
    ///     EvolvingFilletEdge(edge: rim[3], radiusPoints: [(0.0, 1.0), (1.0, 3.0)]),
    ///     EvolvingFilletEdge(edge: rim[6], radiusPoints: [(0.0, 5.0), (1.0, 5.0)]),
    /// ])
    /// ```
    ///
    /// - Parameter edges: Array of edge specifications with radius evolution. Naming the same edge
    ///   twice writes its law twice, and the later one wins.
    /// - Returns: Filleted shape, or nil on failure.
    public func filletEvolving(_ edges: [EvolvingFilletEdge]) -> Shape? {
        guard !edges.isEmpty else { return nil }

        let edgeIndices = edges.map { Int32($0.edgeIndex) }
        let pointCounts = edges.map { Int32($0.radiusPoints.count) }
        var radiusPoints = [OCCTFilletRadiusPoint]()
        for edge in edges {
            for rp in edge.radiusPoints {
                radiusPoints.append(
                    OCCTFilletRadiusPoint(parameter: rp.parameter, radius: rp.radius))
            }
        }

        guard
            let h = OCCTShapeFilletEvolving(
                handle, edgeIndices, Int32(edges.count),
                radiusPoints, pointCounts, nil, nil)
        else { return nil }
        return Shape(handle: h)
    }

    /// ``filletEvolving(_:)``, also reporting which requested edges OCCT declined (#639): the
    /// entry point the census named directly.
    ///
    /// Filleting an open shell's whole edge list SKIPs the edges OCCT declines, with nothing that
    /// says which or how many. See ``filletedWithReport(edges:radius:)`` for the reporting
    /// contract; the meaning is identical here, keyed by ``EvolvingFilletEdge/edgeIndex``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let faces = box.faces().dropFirst().compactMap { Shape.fromFace($0) }
    /// let shell = Shape.sew(shapes: Array(faces))!
    /// let laws = shell.edges().map { EvolvingFilletEdge(edge: $0, radiusPoints: [(0.0, 1.0), (1.0, 1.0)]) }
    /// if let report = shell.filletEvolvingWithReport(laws) {
    ///     print(report.declinedEdgeIndices.count, "of", laws.count, "edges declined")
    /// }
    /// ```
    ///
    /// - Parameter edges: Array of edge specifications with radius evolution. Naming the same edge
    ///   twice writes its law twice, and the later one wins.
    /// - Returns: A ``FilletResult``, or nil on failure.
    public func filletEvolvingWithReport(_ edges: [EvolvingFilletEdge]) -> FilletResult? {
        guard !edges.isEmpty else { return nil }

        let edgeIndices = edges.map { Int32($0.edgeIndex) }
        let pointCounts = edges.map { Int32($0.radiusPoints.count) }
        var radiusPoints = [OCCTFilletRadiusPoint]()
        for edge in edges {
            for rp in edge.radiusPoints {
                radiusPoints.append(
                    OCCTFilletRadiusPoint(parameter: rp.parameter, radius: rp.radius))
            }
        }

        var declined = [Int32](repeating: 0, count: edges.count)
        var declinedCount: Int32 = 0
        let h: OCCTShapeRef? = declined.withUnsafeMutableBufferPointer { declinedBuffer in
            OCCTShapeFilletEvolving(
                handle, edgeIndices, Int32(edges.count),
                radiusPoints, pointCounts,
                declinedBuffer.baseAddress, &declinedCount)
        }
        guard let h else { return nil }
        let declinedIndices = declined.prefix(Int(declinedCount)).map { Int($0) }
        return FilletResult(shape: Shape(handle: h), declinedEdgeIndices: declinedIndices)
    }
    /// Offset a shape with different distances per face.
    ///
    /// - Parameters:
    ///   - defaultOffset: Default offset distance for all faces.
    ///   - faceOffsets: Dictionary mapping 0-based face indices, as ``face(at:)`` and
    ///     ``Face/index`` use, to custom offset distances. An index outside `0..<faceCount`
    ///     fails the call; it used to be skipped, which returned a shape offset by the default
    ///     everywhere and looked exactly like success (#541).
    ///   - tolerance: Offset tolerance (default: 1e-3).
    ///   - joinType: Join type for offset gaps (default: .arc).
    /// - Returns: Offset shape, or nil on failure.
    public func offsetPerFace(
        defaultOffset: Double,
        faceOffsets: [Int: Double],
        tolerance: Double = 1e-3,
        joinType: OffsetJoinType = .arc
    ) -> Shape? {
        let indices = Array(faceOffsets.keys).map { Int32($0) }
        let offsets = Array(faceOffsets.keys).map { faceOffsets[$0]! }

        guard
            let h = OCCTShapeOffsetPerFace(
                handle, defaultOffset,
                indices, offsets,
                Int32(faceOffsets.count),
                tolerance, Int32(joinType.rawValue))
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Semi-Infinite Extrusion (v0.39.0)

    /// Extrude a shape semi-infinitely in a direction.
    ///
    /// Creates a solid that extends infinitely in one direction from the profile.
    /// Useful for half-spaces and trimming operations.
    /// - Parameters:
    ///   - direction: Direction of extrusion
    ///   - infinite: If true, extrude in both directions (infinite); if false, one direction (semi-infinite)
    /// - Returns: Extruded shape, or nil on failure
    public func extrudedSemiInfinite(direction: SIMD3<Double>, infinite: Bool = false) -> Shape? {
        guard
            let h = OCCTShapeExtrudeSemiInfinite(
                handle,
                direction.x, direction.y, direction.z,
                !infinite)
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Prism Until Face (v0.39.0)

    /// Extrude a profile until it reaches a target face, with automatic fuse/cut.
    ///
    /// Uses BRepFeat_MakePrism which is smarter than simple extrusion+boolean.
    /// - Parameters:
    ///   - profile: Profile face to extrude
    ///   - sketchFaceIndex: Face on this shape where the profile sits (0-based)
    ///   - direction: Extrusion direction
    ///   - fuse: If true, add material; if false, remove material
    ///   - untilFaceIndex: Face index (0-based) where extrusion stops. Pass nil for thru-all.
    /// - Returns: Modified shape, or nil on failure
    public func prismUntilFace(
        profile: Shape, sketchFaceIndex: Int,
        direction: SIMD3<Double>, fuse: Bool = true,
        untilFaceIndex: Int? = nil
    ) -> Shape? {
        guard
            let h = OCCTShapePrismUntilFace(
                handle, profile.handle, Int32(sketchFaceIndex),
                direction.x, direction.y, direction.z,
                fuse ? 1 : 0, Int32(untilFaceIndex ?? -1)
            )
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Closed Edge Splitting (v0.41.0)

    /// Split closed (periodic) edges in the shape.
    ///
    /// Periodic edges (like circles) can cause issues in some algorithms.
    /// This splits each closed edge into segments.
    /// - Parameter splitPoints: Number of split points per closed edge (default 1, doubles the edge count)
    /// - Returns: Shape with closed edges split, or nil on failure
    public func dividedClosedEdges(splitPoints: Int = 1) -> Shape? {
        guard let h = OCCTShapeDivideClosedEdges(handle, Int32(splitPoints)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Local Prism (v0.46.0)

    /// Create a local prism (extrusion) from this shape along a direction.
    ///
    /// Uses LocOpe_Prism which tracks generated shapes for each input sub-shape,
    /// providing more detailed operation history than standard extrusion.
    ///
    /// - Parameter direction: Direction and distance of extrusion
    /// - Returns: Extruded shape, or nil on failure
    public func localPrism(direction: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTLocOpePrism(handle, direction.x, direction.y, direction.z) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a local prism with an additional translation.
    ///
    /// - Parameters:
    ///   - direction: Primary direction and distance of extrusion
    ///   - translation: Secondary translation vector
    /// - Returns: Extruded shape, or nil on failure
    public func localPrism(direction: SIMD3<Double>, translation: SIMD3<Double>) -> Shape? {
        guard
            let ref = OCCTLocOpePrismWithTranslation(
                handle, direction.x, direction.y, direction.z,
                translation.x, translation.y, translation.z
            )
        else {
            return nil
        }
        return Shape(handle: ref)
    }
    /// Information about a constrained-fill BSpline surface.
    public struct ConstrainedFillInfo: Sendable {
        /// U-direction BSpline degree.
        public let uDegree: Int
        /// V-direction BSpline degree.
        public let vDegree: Int
        /// Number of control points in U.
        public let uPoles: Int
        /// Number of control points in V.
        public let vPoles: Int
    }

    /// Create a surface by filling a region bounded by 3 or 4 edge curves.
    ///
    /// Uses GeomFill_ConstrainedFilling to create a BSpline surface that
    /// interpolates the given boundary curves.
    ///
    /// - Parameters:
    ///   - edge1: First boundary edge
    ///   - edge2: Second boundary edge
    ///   - edge3: Third boundary edge
    ///   - edge4: Optional fourth boundary edge (nil for 3-sided fill)
    ///   - maxDegree: Maximum BSpline degree (default 8)
    ///   - maxSegments: Maximum number of segments (default 15)
    /// - Returns: Face shape built on the filled surface, or nil on failure
    public static func constrainedFill(
        edge1: Edge, edge2: Edge, edge3: Edge,
        edge4: Edge? = nil,
        maxDegree: Int = 8,
        maxSegments: Int = 15
    ) -> Shape? {
        guard
            let ref = OCCTGeomFillConstrained(
                edge1.handle, edge2.handle,
                edge3.handle, edge4?.handle,
                Int32(maxDegree), Int32(maxSegments))
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get BSpline surface info from a constrained fill result.
    ///
    /// - Returns: Surface info (degrees, pole counts), or nil if not a BSpline surface
    public var constrainedFillInfo: ConstrainedFillInfo? {
        var info = OCCTConstrainedFillingInfo()
        guard OCCTGeomFillConstrainedInfo(handle, &info), info.isValid else { return nil }
        return ConstrainedFillInfo(
            uDegree: Int(info.uDegree),
            vDegree: Int(info.vDegree),
            uPoles: Int(info.uPoles),
            vPoles: Int(info.vPoles)
        )
    }

    // MARK: - LocOpe_LinearForm

    /// Perform a linear form (translation sweep) of this shape with shape tracking.
    ///
    /// Uses LocOpe_LinearForm to sweep a face along a direction vector.
    ///
    /// - Parameters:
    ///   - direction: Direction vector of the sweep
    ///   - start: Start point of the sweep (passed as `from:`)
    ///   - end: End point of the sweep (passed as `to:`)
    /// - Returns: The swept shape, or nil on failure
    public func localLinearForm(
        direction: SIMD3<Double>,
        from start: SIMD3<Double>,
        to end: SIMD3<Double>
    ) -> Shape? {
        guard
            let ref = OCCTLocOpeLinearForm(
                handle,
                direction.x, direction.y, direction.z,
                start.x, start.y, start.z,
                end.x, end.y, end.z)
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_SplitShape

    /// Split a face of this shape by adding a wire on it.
    ///
    /// Uses LocOpe_SplitShape to split a face into multiple parts.
    ///
    /// - Parameters:
    ///   - faceIndex: Index of the face to split (0-based)
    ///   - wire: Wire that lies on the face and defines the split
    /// - Returns: Modified shape with the face split, or nil on failure
    public func splitFace(at faceIndex: Int, with wire: Wire) -> Shape? {
        let wireShape = Shape(handle: OCCTShapeFromWire(wire.handle))
        guard let ref = OCCTLocOpeSplitShapeByWire(handle, Int32(faceIndex), wireShape.handle)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Split an edge of this shape at a parameter.
    ///
    /// Uses LocOpe_SplitShape to split an edge by inserting a vertex.
    ///
    /// - Parameters:
    ///   - edgeIndex: Index of the edge to split (0-based)
    ///   - parameter: Parameter along the edge (0.0 to 1.0)
    /// - Returns: The split edge parts as a compound, or nil on failure
    public func splitEdge(at edgeIndex: Int, parameter: Double) -> Shape? {
        guard let ref = OCCTLocOpeSplitShapeByVertex(handle, Int32(edgeIndex), parameter) else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_SplitDrafts

    /// Split a face with draft angles on both sides of a wire.
    ///
    /// Uses LocOpe_SplitDrafts to create draft surfaces on a shape.
    ///
    /// - Parameters:
    ///   - faceIndex: Index of the face to split (0-based)
    ///   - wire: Wire defining the split line
    ///   - direction: Extraction direction
    ///   - planeOrigin: Origin of the neutral plane
    ///   - planeNormal: Normal of the neutral plane
    ///   - angle: Draft angle in radians
    /// - Returns: Modified shape with draft, or nil on failure
    public func splitDrafts(
        faceIndex: Int, wire: Wire,
        direction: SIMD3<Double>,
        planeOrigin: SIMD3<Double>,
        planeNormal: SIMD3<Double>,
        angle: Double
    ) -> Shape? {
        let wireShape = Shape(handle: OCCTShapeFromWire(wire.handle))
        guard
            let ref = OCCTLocOpeSplitDrafts(
                handle, Int32(faceIndex), wireShape.handle,
                direction.x, direction.y, direction.z,
                planeOrigin.x, planeOrigin.y, planeOrigin.z,
                planeNormal.x, planeNormal.y, planeNormal.z,
                angle)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Shape modification history for tracking what happened during operations.
    public class History {
        let historyRef: OCCTHistoryRef

        /// Create an empty history.
        public init?() {
            guard let ref = OCCTHistoryCreate() else { return nil }
            historyRef = ref
        }

        deinit {
            OCCTHistoryDestroy(historyRef)
        }

        /// Record that an initial shape was modified into a new shape.
        public func addModified(initial: Shape, modified: Shape) {
            OCCTHistoryAddModified(historyRef, initial.handle, modified.handle)
        }

        /// Record that an initial shape generated a new shape.
        public func addGenerated(initial: Shape, generated: Shape) {
            OCCTHistoryAddGenerated(historyRef, initial.handle, generated.handle)
        }

        /// Record that a shape was removed.
        public func remove(_ shape: Shape) {
            OCCTHistoryRemove(historyRef, shape.handle)
        }

        /// Check if a shape was recorded as removed.
        public func isRemoved(_ shape: Shape) -> Bool {
            OCCTHistoryIsRemoved(historyRef, shape.handle)
        }

        /// Whether any modifications were recorded.
        public var hasModified: Bool {
            OCCTHistoryHasModified(historyRef)
        }

        /// Whether any generations were recorded.
        public var hasGenerated: Bool {
            OCCTHistoryHasGenerated(historyRef)
        }

        /// Whether any removals were recorded.
        public var hasRemoved: Bool {
            OCCTHistoryHasRemoved(historyRef)
        }

        /// Number of shapes the given initial shape was modified to.
        public func modifiedCount(of shape: Shape) -> Int {
            Int(OCCTHistoryModifiedCount(historyRef, shape.handle))
        }

        /// Number of shapes the given initial shape generated.
        public func generatedCount(of shape: Shape) -> Int {
            Int(OCCTHistoryGeneratedCount(historyRef, shape.handle))
        }
    }

    // MARK: - BRepFill_Generator

    /// Create a ruled shell by lofting between multiple wire sections.
    ///
    /// Each pair of adjacent wires generates a ruled surface between them.
    /// Wires should have the same number of edges for best results.
    ///
    /// - Parameter wires: Array of at least 2 wires to loft between
    /// - Returns: Shell shape connecting the wires, or nil on failure
    public static func ruledShell(from wires: [Wire]) -> Shape? {
        guard wires.count >= 2 else { return nil }
        let handles: [OCCTWireRef] = wires.map { $0.handle }
        return handles.withUnsafeBufferPointer { buffer in
            guard let h = OCCTBRepFillGenerator(buffer.baseAddress!, Int32(wires.count)) else {
                return nil
            }
            return Shape(handle: h)
        }
    }

    // MARK: - BRepFill_AdvancedEvolved

    /// Create an evolved solid from a spine wire and profile wire.
    ///
    /// The profile is swept along the spine, creating a solid. The profile is
    /// oriented perpendicular to the spine at each point.
    ///
    /// - Parameters:
    ///   - spine: Wire defining the sweep path
    ///   - profile: Wire defining the cross-section
    ///   - tolerance: Geometric tolerance (default 1e-3)
    ///   - solid: Whether to produce a solid (default true)
    /// - Returns: Evolved shape, or nil on failure
    public static func advancedEvolved(
        spine: Wire, profile: Wire,
        tolerance: Double = 1e-3, solid: Bool = true
    ) -> Shape? {
        guard
            let h = OCCTBRepFillAdvancedEvolved(
                spine.handle, profile.handle, tolerance, solid)
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFill_OffsetWire

    /// Offset a planar wire on its face.
    ///
    /// Creates a new wire offset from the edges of the given face.
    /// Positive offset expands outward, negative shrinks inward.
    ///
    /// - Parameters:
    ///   - face: Face containing the wire to offset
    ///   - offset: Signed offset distance
    /// - Returns: Offset wire shape, or nil on failure
    public static func offsetWire(face: Face, offset: Double) -> Shape? {
        guard let h = OCCTBRepFillOffsetWire(face.handle, offset) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFill_Draft

    /// Create a draft surface from a wire along a direction with a taper angle.
    ///
    /// The wire is projected along the given direction for the specified length,
    /// with faces tapered at the given angle from the direction.
    ///
    /// - Parameters:
    ///   - wire: Wire defining the base profile
    ///   - direction: Draft direction
    ///   - angle: Taper angle in radians
    ///   - length: Draft length
    /// - Returns: Draft shape, or nil on failure
    public static func draft(
        wire: Wire, direction: SIMD3<Double>,
        angle: Double, length: Double
    ) -> Shape? {
        guard
            let h = OCCTBRepFillDraft(
                wire.handle, direction.x, direction.y, direction.z,
                angle, length)
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFill_CompatibleWires

    /// Make wires compatible for lofting (same number of edges, aligned).
    ///
    /// Resamples wires so they have the same number of edges and are oriented
    /// consistently, which improves lofting quality.
    ///
    /// - Parameter wires: Array of at least 2 wires to normalize
    /// - Returns: Array of compatible wires, or nil on failure
    public static func compatibleWires(_ wires: [Wire]) -> [Wire]? {
        guard wires.count >= 2 else { return nil }
        let handles: [OCCTWireRef] = wires.map { $0.handle }
        var outHandles = [OCCTWireRef?](repeating: nil, count: wires.count)
        let count = handles.withUnsafeBufferPointer { inBuf in
            outHandles.withUnsafeMutableBufferPointer { outBuf in
                OCCTBRepFillCompatibleWires(
                    inBuf.baseAddress!, Int32(wires.count), outBuf.baseAddress!)
            }
        }
        guard count > 0 else { return nil }
        return (0..<Int(count)).compactMap { i in
            if let h = outHandles[i] { return Wire(handle: h) }
            return nil
        }
    }

    // MARK: - LocOpe_BuildShape

    /// Build a shape from the faces of this shape.
    ///
    /// Extracts all faces and reconstructs them into a shell or solid.
    ///
    /// - Returns: Rebuilt shape, or nil on failure
    public func builtFromFaces() -> Shape? {
        guard let h = OCCTLocOpeBuildShape(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BOPAlgo Splitter (v0.61.0)

    /// Split shapes by tool shapes using BOPAlgo_Splitter.
    ///
    /// Partitions the object shapes using the tool shapes as cutting geometry.
    ///
    /// - Parameters:
    ///   - objects: Shapes to be split
    ///   - tools: Shapes used as splitting tools
    /// - Returns: Result shape containing all split fragments, or nil on failure
    public static func split(objects: [Shape], by tools: [Shape]) -> Shape? {
        let objPtrs = objects.map { $0.handle as OCCTShapeRef? }
        let toolPtrs = tools.map { $0.handle as OCCTShapeRef? }
        guard
            let h = objPtrs.withUnsafeBufferPointer({ objBuf in
                toolPtrs.withUnsafeBufferPointer({ toolBuf in
                    OCCTBOPAlgoSplit(
                        objBuf.baseAddress, Int32(objBuf.count),
                        toolBuf.baseAddress, Int32(toolBuf.count))
                })
            })
        else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BOPAlgo ArgumentAnalyzer (v0.61.0)

    /// Boolean operation type for argument analysis.
    public enum BooleanOperation: Int32 {
        case fuse = 0
        case common = 1
        case cut = 2
        case cut21 = 3
        case section = 4
    }

    /// Analyze whether two shapes are valid for a Boolean operation.
    ///
    /// Checks for self-intersection, small edges, and argument type compatibility.
    ///
    /// - Parameters:
    ///   - shape1: First shape (object)
    ///   - shape2: Second shape (tool)
    ///   - operation: The Boolean operation to check
    /// - Returns: true if the shapes are valid for the operation
    public static func analyzeBoolean(
        _ shape1: Shape, _ shape2: Shape,
        operation: BooleanOperation = .fuse
    ) -> Bool {
        return OCCTBOPAlgoAnalyzeArguments(shape1.handle, shape2.handle, operation.rawValue)
    }

    // MARK: LocOpe_BuildWires

    /// Build wires from the edges of one face, or of the whole shape.
    ///
    /// - Parameter faceIndex: 0-based face index, as ``face(at:)`` and ``Face/index`` use.
    ///   Any negative value means every edge of the shape. The sentinel used to be `0`, which
    ///   collided with the first face's own index and left that face unaddressable (#541).
    /// - Returns: The wires built from those edges, or nil on failure.
    ///
    /// ```swift
    /// let box = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
    /// let allEdges = box.buildWires(faceIndex: -1)!   // every edge of the box
    /// let firstFace = box.buildWires(faceIndex: 0)!   // just face 0's edges
    /// ```
    public func buildWires(faceIndex: Int32 = -1) -> [Shape]? {
        var outWires: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard OCCTLocOpeBuildWires(handle, faceIndex, &outWires, &outCount) else { return nil }
        guard let wires = outWires else { return [] }
        defer { free(wires) }
        var result = [Shape]()
        for i in 0..<Int(outCount) {
            if let h = wires[i] {
                result.append(Shape(handle: h))
            }
        }
        return result
    }

    // MARK: LocOpe_WiresOnShape + LocOpe_Spliter

    /// Split a face of this shape by projecting a wire onto it.
    ///
    /// - Note: Only the **first** wire of `wire` is used. Passing a shape that holds several
    ///   wires splits by one of them and silently ignores the rest; call once per wire.
    ///
    /// - Parameters:
    ///   - wire: The splitting wire
    ///   - faceIndex: 0-based index of the face to split, as ``face(at:)`` and ``Face/index``
    ///     use. It was 1-based, so face 0 could not be named at all (#541).
    /// - Returns: The shape with that face split by the wire, or nil on failure.
    public func splitByWireOnFace(_ wire: Shape, faceIndex: Int32) -> Shape? {
        guard let h = OCCTLocOpeSplitByWireOnFace(handle, wire.handle, faceIndex) else {
            return nil
        }
        return Shape(handle: h)
    }

    // MARK: - BRepOffset_SimpleOffset

    /// Create a simple surface offset of the shape.
    public func simpleOffsetShape(distance: Double, tolerance: Double = 1e-3) -> Shape? {
        guard let h = OCCTBRepOffsetSimpleOffset(handle, distance, tolerance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepFeat_Builder

    /// Feature-based fuse (union with part selection).
    public func featFuse(with tool: Shape) -> Shape? {
        guard let h = OCCTBRepFeatBuilderFuse(handle, tool.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Feature-based cut (subtraction with part selection).
    public func featCut(with tool: Shape) -> Shape? {
        guard let h = OCCTBRepFeatBuilderCut(handle, tool.handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepOffset_Offset

    /// Offset a face by a distance, creating a new offset face.
    public func offsetFace(distance: Double) -> Shape? {
        guard let h = OCCTBRepOffsetOffsetFace(handle, distance) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - v0.65.0: Shape Processing Completions + Boolean Completions

    // MARK: - BOPAlgo_RemoveFeatures

    // MARK: - BOPAlgo_Section

    /// Compute section (intersection curves/vertices) between this shape and tools.
    ///
    /// Uses BOPAlgo_Section to find intersection edges and vertices.
    ///
    /// - Parameter tools: Tool shapes to intersect with
    /// - Returns: Compound of edges/vertices at intersections, or nil on failure
    public func section(with tools: [Shape]) -> Shape? {
        let objHandles = [handle as OCCTShapeRef]
        let toolHandles = tools.map { $0.handle as OCCTShapeRef }
        guard
            let ref = objHandles.withUnsafeBufferPointer({ objBuf in
                toolHandles.withUnsafeBufferPointer({ toolBuf in
                    OCCTBOPAlgoSection(
                        objBuf.baseAddress!, Int32(objBuf.count),
                        toolBuf.baseAddress!, Int32(toolBuf.count))
                })
            })
        else { return nil }
        return Shape(handle: ref)
    }

    /// Compute section between multiple shapes.
    ///
    /// - Parameter shapes: Array of shapes to compute section between
    /// - Returns: Compound of edges/vertices at intersections, or nil on failure
    public static func section(shapes: [Shape]) -> Shape? {
        let handles = shapes.map { $0.handle as OCCTShapeRef }
        guard handles.count >= 2 else { return nil }
        return handles.withUnsafeBufferPointer({ buf in
            // Pass all shapes as objects (BOPAlgo_Section treats all arguments equally)
            let empty = [OCCTShapeRef]()
            return empty.withUnsafeBufferPointer({ emptyBuf in
                guard
                    let ref = OCCTBOPAlgoSection(
                        buf.baseAddress!, Int32(buf.count),
                        emptyBuf.baseAddress!, Int32(0))
                else { return nil }
                return Shape(handle: ref)
            })
        })
    }

    // MARK: - BOPAlgo Builder (v0.70.0)

    /// Build faces from edges on a base face surface.
    ///
    /// Uses BOPAlgo_BuilderFace to construct faces from a set of edges
    /// that lie on this face's surface.
    ///
    /// - Parameter edges: Array of edge shapes to build faces from
    /// - Returns: Array of result face shapes, or nil on failure
    public func buildFaces(from edges: [Shape]) -> [Shape]? {
        let edgeHandles = edges.map { $0.handle as OCCTShapeRef }
        var outFaces: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard
            edgeHandles.withUnsafeBufferPointer({ buf in
                OCCTBOPAlgoBuilderFace(
                    handle, buf.baseAddress!, Int32(buf.count), &outFaces, &outCount)
            })
        else { return nil }
        defer { outFaces?.deallocate() }
        return (0..<Int(outCount)).compactMap { i in
            if let ref = outFaces?[i] { return Shape(handle: ref) }
            return nil
        }
    }

    /// Build solids from faces.
    ///
    /// Uses BOPAlgo_BuilderSolid to construct solids from a closed set of faces.
    ///
    /// - Parameter faces: Array of face shapes forming closed volumes
    /// - Returns: Array of result solid shapes, or nil on failure
    public static func buildSolids(from faces: [Shape]) -> [Shape]? {
        let faceHandles = faces.map { $0.handle as OCCTShapeRef }
        var outSolids: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard
            faceHandles.withUnsafeBufferPointer({ buf in
                OCCTBOPAlgoBuilderSolid(buf.baseAddress!, Int32(buf.count), &outSolids, &outCount)
            })
        else { return nil }
        defer { outSolids?.deallocate() }
        return (0..<Int(outCount)).compactMap { i in
            if let ref = outSolids?[i] { return Shape(handle: ref) }
            return nil
        }
    }

    /// Split a shell into connected components.
    ///
    /// Uses BOPAlgo_ShellSplitter to separate disjoint parts of a shell.
    ///
    /// - Returns: Array of shell shapes (connected components), or nil on failure
    public func splitShell() -> [Shape]? {
        var outShells: UnsafeMutablePointer<OCCTShapeRef?>?
        var outCount: Int32 = 0
        guard OCCTBOPAlgoShellSplitter(handle, &outShells, &outCount) else { return nil }
        defer { outShells?.deallocate() }
        return (0..<Int(outCount)).compactMap { i in
            if let ref = outShells?[i] { return Shape(handle: ref) }
            return nil
        }
    }

    /// Convert a compound of edges into wires.
    ///
    /// Uses BOPAlgo_Tools::EdgesToWires to connect edges into wires.
    ///
    /// - Parameter tolerance: Connection tolerance (default 1e-7)
    /// - Returns: Compound of wires, or nil on failure
    public func edgesToWires(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTBOPAlgoEdgesToWires(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Convert a compound of wires into faces.
    ///
    /// Uses BOPAlgo_Tools::WiresToFaces to build planar faces from wires.
    ///
    /// - Parameter tolerance: Face building tolerance (default 1e-7)
    /// - Returns: Compound of faces, or nil on failure
    public func wiresToFaces(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTBOPAlgoWiresToFaces(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BOPTools (v0.70.0)

    /// Get the normal to a face at an edge location.
    ///
    /// Uses BOPTools_AlgoTools3D::GetNormalToFaceOnEdge.
    ///
    /// - Parameters:
    ///   - edge: Edge on the face
    ///   - face: Face containing the edge
    /// - Returns: Normal direction, or nil on failure
    public static func normalOnEdge(edge: Shape, face: Shape) -> SIMD3<Double>? {
        var nx: Double = 0
        var ny: Double = 0
        var nz: Double = 0
        guard OCCTBOPToolsNormalOnEdge(edge.handle, face.handle, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    /// Find a point strictly inside a face.
    ///
    /// Uses BOPTools_AlgoTools3D::PointInFace.
    ///
    /// - Returns: A 3D point inside this face, or nil on failure
    public func pointInFace() -> SIMD3<Double>? {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        guard OCCTBOPToolsPointInFace(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Check if this shell is open (not all edges shared by two faces).
    ///
    /// Uses BOPTools_AlgoTools::IsOpenShell.
    public var isOpenShell: Bool {
        OCCTBOPToolsIsOpenShell(handle)
    }

    // MARK: - BOPAlgo_WireSplitter (v0.71.0)

    /// Build a wire from a list of edges using BOPAlgo_WireSplitter::MakeWire.
    ///
    /// This static utility assembles edges into a connected wire.
    /// - Parameter edges: Array of edge shapes to connect.
    /// - Returns: Result wire as a shape, or nil on failure.
    public static func makeWire(from edges: [Shape]) -> Shape? {
        let handles = edges.map { $0.handle as OCCTShapeRef }
        guard
            let ref = handles.withUnsafeBufferPointer({ buf in
                OCCTBOPAlgoMakeWire(buf.baseAddress!, Int32(edges.count))
            })
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - BRepFeat_SplitShape (v0.71.0)

    /// Split this shape by adding an edge to a face.
    ///
    /// Uses BRepFeat_SplitShape to split the face that the edge lies on.
    /// - Parameters:
    ///   - edge: Edge to add as split line.
    ///   - face: Face on which to add the edge.
    /// - Returns: Result shape with split face, or nil on failure.
    public func splitByEdge(_ edge: Shape, onFace face: Shape) -> Shape? {
        guard let ref = OCCTBRepFeatSplitShapeEdge(handle, edge.handle, face.handle) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Split this shape by adding a wire to a face.
    ///
    /// Uses BRepFeat_SplitShape to split the face along the wire.
    /// - Parameters:
    ///   - wire: Wire to add as split line.
    ///   - face: Face on which to add the wire.
    /// - Returns: Result shape with split face, or nil on failure.
    public func splitByWire(_ wire: Shape, onFace face: Shape) -> Shape? {
        guard let ref = OCCTBRepFeatSplitShapeWire(handle, wire.handle, face.handle) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Result of a split-shape operation with left/right face information.
    public struct SplitShapeResult: Sendable {
        /// The resulting split shape.
        public let shape: Shape
        /// Faces on the left side of the split.
        public let leftFaces: [Shape]
        /// Faces on the right side of the split.
        public let rightFaces: [Shape]
    }

    /// Split this shape with multiple edge-on-face pairs, returning left/right faces.
    ///
    /// Uses BRepFeat_SplitShape with Left()/Right() queries.
    /// - Parameter edgesOnFaces: Array of (edge, face) pairs. Each edge is added to the corresponding face.
    /// - Returns: Split result with left and right faces, or nil on failure.
    public func splitWithSides(edgesOnFaces: [(edge: Shape, face: Shape)]) -> SplitShapeResult? {
        var handles: [OCCTShapeRef] = []
        for pair in edgesOnFaces {
            handles.append(pair.edge.handle)
            handles.append(pair.face.handle)
        }
        var outLeft: UnsafeMutablePointer<OCCTShapeRef?>?
        var outLeftCount: Int32 = 0
        var outRight: UnsafeMutablePointer<OCCTShapeRef?>?
        var outRightCount: Int32 = 0
        guard
            let ref = handles.withUnsafeBufferPointer({ buf in
                OCCTBRepFeatSplitShapeWithSides(
                    handle,
                    buf.baseAddress!.withMemoryRebound(
                        to: OCCTShapeRef.self, capacity: handles.count
                    ) { $0 },
                    Int32(edgesOnFaces.count),
                    &outLeft, &outLeftCount, &outRight, &outRightCount)
            })
        else { return nil }

        var leftShapes: [Shape] = []
        if let outLeft = outLeft {
            for i in 0..<Int(outLeftCount) {
                if let h = outLeft[i] { leftShapes.append(Shape(handle: h)) }
            }
            free(outLeft)
        }
        var rightShapes: [Shape] = []
        if let outRight = outRight {
            for i in 0..<Int(outRightCount) {
                if let h = outRight[i] { rightShapes.append(Shape(handle: h)) }
            }
            free(outRight)
        }
        return SplitShapeResult(
            shape: Shape(handle: ref), leftFaces: leftShapes, rightFaces: rightShapes)
    }

    // MARK: - BRepFeat_MakeCylindricalHole (v0.71.0, unified #496)

    /// How a feature-drilled hole is bounded.
    ///
    /// `BRepFeat_MakeCylindricalHole` offers five ways to say where the hole stops, and they are
    /// not interchangeable. In particular ``throughAll`` does not start at the axis origin, and
    /// ``blind(depth:)`` will not drill past the far face, see each case.
    ///
    /// ```swift
    /// let plate = Shape.box(width: 50, height: 50, depth: 20)!
    /// let origin = SIMD3<Double>(0, 0, 15)     // 5mm above the top face
    /// let axis = SIMD3<Double>(0, 0, -1)
    ///
    /// // Bounded by the plate's own entry and exit faces:
    /// let through = plate.cylindricalHole(axisOrigin: origin, axisDirection: axis,
    ///                                     radius: 5, extent: .untilEnd)
    ///
    /// // A 6mm-deep blind hole, measured from the origin, so 1mm into the plate:
    /// let blind = plate.cylindricalHole(axisOrigin: origin, axisDirection: axis,
    ///                                   radius: 5, extent: .blind(depth: 6))
    /// ```
    public enum CylindricalHoleExtent: Sendable, Equatable {
        /// `Perform(R)`, an **infinite** cylinder, extending both ways along the axis.
        ///
        /// The axis origin anchors the axis; it is not where the hole starts. Drilling "down" from
        /// a point inside a solid removes the material above it too. This is the one extent that
        /// tolerates a non-solid input.
        case throughAll
        /// `PerformUntilEnd(R)`, bounded by the stock's own first and last faces along the axis.
        ///
        /// The forward-bounded through hole most callers reach for ``throughAll`` expecting. Every
        /// body the axis crosses beyond the entry face is drilled, so a stack of plates is bored
        /// all the way through.
        case untilEnd
        /// `PerformThruNext(R)`, stops at the next face after the origin.
        case thruNext
        /// `PerformBlind(R, depth)`, a partial-depth hole, `depth` measured from the axis origin.
        ///
        /// The only extent that can report ``CylindricalHoleStatus/holeTooLong``: a depth that
        /// would leave the far side of the stock is refused rather than drilled through. Use
        /// ``untilEnd`` or ``Shape/drilled(at:direction:radius:depth:)`` if overshooting should
        /// simply drill through.
        case blind(depth: Double)
        /// `Perform(R, PFrom, PTo)`, the hole bounded by the entry/exit face pair that the
        /// parameter window `from...to` selects. Parameters are measured from the axis origin, in
        /// units of the (normalized) direction.
        ///
        /// The window **chooses a face pair; it does not trim the cut**. A window lying strictly
        /// inside one body still drills all the way through that body, and a window that names no
        /// face pair, the gap between two plates, say, is ``CylindricalHoleStatus/invalidPlacement``.
        /// Its use is picking *which* body to drill in a stack: a window over one plate drills that
        /// plate, and a window spanning several drills all of them.
        case range(from: Double, to: Double)

        /// The (mode, p0, p1) triple the bridge reads.
        var bridgeParameters: (mode: Int32, p0: Double, p1: Double) {
            switch self {
            case .throughAll: return (0, 0, 0)
            case .untilEnd: return (1, 0, 0)
            case .thruNext: return (2, 0, 0)
            case .blind(let depth): return (3, depth, 0)
            case .range(let from, let to): return (4, from, to)
            }
        }
    }

    /// Status result for cylindrical hole operations.
    public enum CylindricalHoleStatus: Int32, Sendable {
        /// The request is drillable.
        case noError = 0
        /// The axis does not meet the shape in a way this extent can use, including a request with
        /// no direction, or a radius at or below `Precision::Confusion`.
        case invalidPlacement = 1
        /// A ``CylindricalHoleExtent/blind(depth:)`` depth that would leave the stock. Only that
        /// extent produces this.
        case holeTooLong = 2
        /// OCCT raised something the bridge does not recognise.
        case unknown = 3
    }

    /// Drill a cylindrical hole with `BRepFeat_MakeCylindricalHole`, OCCT's feature-drilling
    /// operator, bounded by `extent`.
    ///
    /// Wants a solid: every extent but ``CylindricalHoleExtent/throughAll`` reports
    /// ``CylindricalHoleStatus/invalidPlacement`` for a shell or a face. For the
    /// boolean-subtraction drill, which starts exactly where you tell it to, accepts any shape,
    /// and treats an over-long depth as a through hole, see
    /// ``drilled(at:direction:radius:depth:)``. Neither subsumes the other (#496).
    ///
    /// Ask ``cylindricalHoleStatus(axisOrigin:axisDirection:radius:extent:)`` first when you want to
    /// know *why* a request is not drillable; `nil` here collapses every reason into one.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis; any non-zero vector.
    ///   - radius: Hole radius; must exceed `Precision::Confusion` (1e-7).
    ///   - extent: Where the hole stops.
    /// - Returns: Shape with hole, or nil on failure.
    ///
    /// ```swift
    /// let plate = Shape.box(width: 50, height: 50, depth: 20)!
    /// let bored = plate.cylindricalHole(axisOrigin: SIMD3(0, 0, 15),
    ///                                   axisDirection: SIMD3(0, 0, -1),
    ///                                   radius: 5, extent: .untilEnd)
    /// ```
    public func cylindricalHole(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>,
        radius: Double, extent: CylindricalHoleExtent
    ) -> Shape? {
        let (mode, p0, p1) = extent.bridgeParameters
        guard
            let ref = OCCTBRepFeatCylindricalHole(
                handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisDirection.x, axisDirection.y, axisDirection.z,
                radius, mode, p0, p1)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Ask what ``cylindricalHole(axisOrigin:axisDirection:radius:extent:)`` would report for this
    /// exact request, without building the result.
    ///
    /// The extent is part of the question, because the answer depends on it: a radius wider than
    /// the whole solid is ``CylindricalHoleStatus/noError`` for ``CylindricalHoleExtent/throughAll``
    /// and ``CylindricalHoleStatus/invalidPlacement`` for ``CylindricalHoleExtent/thruNext``, and
    /// ``CylindricalHoleStatus/holeTooLong`` exists only under ``CylindricalHoleExtent/blind(depth:)``.
    ///
    /// - Returns: The status the matching drill would produce. ``CylindricalHoleStatus/noError`` if
    ///   and only if that drill would return a shape.
    ///
    /// ```swift
    /// let plate = Shape.box(width: 50, height: 50, depth: 20)!
    /// let origin = SIMD3<Double>(0, 0, 11), axis = SIMD3<Double>(0, 0, -1)
    /// if plate.cylindricalHoleStatus(axisOrigin: origin, axisDirection: axis,
    ///                                radius: 5, extent: .blind(depth: 100)) == .holeTooLong {
    ///     // ... too deep for this stock; drill it through instead
    /// }
    /// ```
    public func cylindricalHoleStatus(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>,
        radius: Double,
        extent: CylindricalHoleExtent
    ) -> CylindricalHoleStatus {
        let (mode, p0, p1) = extent.bridgeParameters
        let raw = OCCTBRepFeatCylindricalHoleStatus(
            handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            radius, mode, p0, p1)
        return CylindricalHoleStatus(rawValue: raw) ?? .unknown
    }

    /// Drill a through cylindrical hole in this shape.
    ///
    /// Uses `BRepFeat_MakeCylindricalHole::Perform`, whose cylinder is **infinite in both
    /// directions**: the axis origin anchors the axis rather than starting the hole. For a hole
    /// bounded by the stock's own faces, prefer
    /// ``cylindricalHole(axisOrigin:axisDirection:radius:extent:)`` with
    /// ``CylindricalHoleExtent/untilEnd``.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    /// - Returns: Shape with hole, or nil on failure.
    public func cylindricalHole(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double
    ) -> Shape? {
        cylindricalHole(
            axisOrigin: axisOrigin, axisDirection: axisDirection,
            radius: radius, extent: .throughAll)
    }

    /// Drill a blind cylindrical hole in this shape.
    ///
    /// Uses `BRepFeat_MakeCylindricalHole::PerformBlind` for a partial-depth hole, `depth` measured
    /// from the axis origin. A depth that would leave the far side of the stock is refused, not
    /// drilled through, see ``CylindricalHoleStatus/holeTooLong``.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    ///   - depth: Hole depth.
    /// - Returns: Shape with hole, or nil on failure.
    public func cylindricalHoleBlind(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double, depth: Double
    ) -> Shape? {
        cylindricalHole(
            axisOrigin: axisOrigin, axisDirection: axisDirection,
            radius: radius, extent: .blind(depth: depth))
    }

    /// Drill a cylindrical hole through to the next face.
    ///
    /// Uses `BRepFeat_MakeCylindricalHole::PerformThruNext`.
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    /// - Returns: Shape with hole, or nil on failure.
    public func cylindricalHoleThruNext(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double
    ) -> Shape? {
        cylindricalHole(
            axisOrigin: axisOrigin, axisDirection: axisDirection,
            radius: radius, extent: .thruNext)
    }

    /// Check the status of a through-all cylindrical hole operation without modifying the shape.
    ///
    /// Answers for ``CylindricalHoleExtent/throughAll`` only. Pass the extent you are actually about
    /// to drill to ``cylindricalHoleStatus(axisOrigin:axisDirection:radius:extent:)``, this
    /// spelling reports `.noError` for requests that ``cylindricalHoleThruNext(axisOrigin:axisDirection:radius:)``
    /// and ``cylindricalHoleBlind(axisOrigin:axisDirection:radius:depth:)`` then refuse.
    ///
    /// - Parameters:
    ///   - axisOrigin: Origin point of the hole axis.
    ///   - axisDirection: Direction of the hole axis.
    ///   - radius: Hole radius.
    /// - Returns: Status indicating whether the through-all hole can be drilled.
    public func cylindricalHoleStatus(
        axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>, radius: Double
    ) -> CylindricalHoleStatus {
        cylindricalHoleStatus(
            axisOrigin: axisOrigin, axisDirection: axisDirection,
            radius: radius, extent: .throughAll)
    }

    // MARK: - BRepFeat_Gluer (v0.71.0)

    /// Glue another shape onto this shape by binding matching faces.
    ///
    /// Uses BRepFeat_Gluer to merge shapes along coincident faces.
    /// - Parameters:
    ///   - gluedShape: Shape to glue onto this shape.
    ///   - facePairs: Matching face pairs, (base face from this shape, glued face from gluedShape).
    /// - Returns: Result glued shape, or nil on failure.
    public func glue(_ gluedShape: Shape, facePairs: [(base: Shape, glued: Shape)]) -> Shape? {
        let baseFaces = facePairs.map { $0.base.handle as OCCTShapeRef }
        let gluedFaces = facePairs.map { $0.glued.handle as OCCTShapeRef }
        guard
            let ref = baseFaces.withUnsafeBufferPointer({ baseBuf in
                gluedFaces.withUnsafeBufferPointer({ gluedBuf in
                    OCCTBRepFeatGluer(
                        handle, gluedShape.handle,
                        baseBuf.baseAddress!, gluedBuf.baseAddress!,
                        Int32(facePairs.count))
                })
            })
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_WiresOnShape + LocOpe_Spliter (v0.71.0)

    /// Result of LocOpe_Spliter split operation.
    public struct LocOpeSplitResult: Sendable {
        /// The resulting split shape.
        public let shape: Shape
        /// Faces directly on the left of the split.
        public let directLeftFaces: [Shape]
    }

    /// Split this shape by projecting wires onto faces using LocOpe_Spliter.
    ///
    /// Uses LocOpe_WiresOnShape to bind wires to faces, then LocOpe_Spliter to split.
    ///
    /// - Note: Each pair contributes only the **first** wire of its `wire` shape. A pair
    ///   whose shape holds several wires binds one of them and ignores the rest; give each
    ///   wire its own pair. A pair whose shape holds no wire at all is skipped silently.
    ///
    /// - Parameter wiresOnFaces: Array of (wire, face) pairs to bind.
    /// - Returns: Split result with direct-left faces, or nil on failure.
    public func locOpeSplit(wiresOnFaces: [(wire: Shape, face: Shape)]) -> LocOpeSplitResult? {
        var handles: [OCCTShapeRef] = []
        for pair in wiresOnFaces {
            handles.append(pair.wire.handle)
            handles.append(pair.face.handle)
        }
        var outDirectLeft: UnsafeMutablePointer<OCCTShapeRef?>?
        var outDirectLeftCount: Int32 = 0
        guard
            let ref = handles.withUnsafeBufferPointer({ buf in
                OCCTLocOpeSplitByWires(
                    handle,
                    buf.baseAddress!.withMemoryRebound(
                        to: OCCTShapeRef.self, capacity: handles.count
                    ) { $0 },
                    Int32(wiresOnFaces.count),
                    &outDirectLeft, &outDirectLeftCount)
            })
        else { return nil }

        var dlShapes: [Shape] = []
        if let outDirectLeft = outDirectLeft {
            for i in 0..<Int(outDirectLeftCount) {
                if let h = outDirectLeft[i] { dlShapes.append(Shape(handle: h)) }
            }
            free(outDirectLeft)
        }
        return LocOpeSplitResult(shape: Shape(handle: ref), directLeftFaces: dlShapes)
    }

    /// Split this shape by automatically binding wire edges to shape faces.
    ///
    /// Uses LocOpe_WiresOnShape::Add + BindAll, then LocOpe_Spliter.
    /// - Parameter wires: Wires to project and split by.
    /// - Returns: Result shape, or nil on failure.
    public func locOpeSplitAuto(wires: [Shape]) -> Shape? {
        let wireHandles = wires.map { $0.handle as OCCTShapeRef }
        guard
            let ref = wireHandles.withUnsafeBufferPointer({ buf in
                OCCTLocOpeSplitByWiresAuto(handle, buf.baseAddress!, Int32(wires.count))
            })
        else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - LocOpe_Gluer (v0.72.0)

    /// Glue another shape onto this shape using LocOpe_Gluer with face and edge binding.
    ///
    /// - Parameters:
    ///   - gluedShape: Shape to glue.
    ///   - facePairs: At least one matching face pair required (base from this shape, glued from gluedShape).
    ///     Empty array will return nil.
    ///   - edgePairs: Optional matching edge pairs for precise alignment.
    /// - Returns: Result shape, or nil on failure (including empty facePairs).
    public func locOpeGlue(
        _ gluedShape: Shape,
        facePairs: [(base: Shape, glued: Shape)],
        edgePairs: [(base: Shape, glued: Shape)] = []
    ) -> Shape? {
        let baseFaces = facePairs.map { $0.base.handle as OCCTShapeRef }
        let gluedFaces = facePairs.map { $0.glued.handle as OCCTShapeRef }
        let baseEdges = edgePairs.map { $0.base.handle as OCCTShapeRef? }
        let gluedEdges = edgePairs.map { $0.glued.handle as OCCTShapeRef? }

        let ref: OCCTShapeRef? = baseFaces.withUnsafeBufferPointer { baseFBuf in
            gluedFaces.withUnsafeBufferPointer { gluedFBuf in
                if edgePairs.isEmpty {
                    return OCCTLocOpeGlue(
                        handle, gluedShape.handle,
                        baseFBuf.baseAddress!, gluedFBuf.baseAddress!,
                        Int32(facePairs.count), nil, nil, 0)
                } else {
                    return baseEdges.withUnsafeBufferPointer { baseEBuf in
                        gluedEdges.withUnsafeBufferPointer { gluedEBuf in
                            OCCTLocOpeGlue(
                                handle, gluedShape.handle,
                                baseFBuf.baseAddress!, gluedFBuf.baseAddress!,
                                Int32(facePairs.count),
                                baseEBuf.baseAddress!, gluedEBuf.baseAddress!,
                                Int32(edgePairs.count))
                        }
                    }
                }
            }
        }
        guard let ref else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - FilletSurf_Builder (v0.72.0)

    /// Information about a computed fillet surface.
    public struct FilletSurfaceInfo: Sendable {
        /// The fillet surface geometry.
        public let surface: Surface
        /// First support face.
        public let supportFace1: Shape
        /// Second support face.
        public let supportFace2: Shape
        /// Approximation tolerance achieved.
        public let tolerance: Double
        /// First parameter on edge.
        public let firstParameter: Double
        /// Last parameter on edge.
        public let lastParameter: Double
        /// Start section status.
        public let startStatus: Int
        /// End section status.
        public let endStatus: Int
    }

    /// Result of fillet surface computation.
    public struct FilletSurfaceResult: Sendable {
        /// Fillet surface info for each computed surface.
        public let surfaces: [FilletSurfaceInfo]
        /// Status: 0=ok, 1=notOk, 2=partial.
        public let status: Int
    }

    /// Compute fillet surfaces on this shape using FilletSurf_Builder.
    ///
    /// Returns geometric fillet surface info (NURBS surfaces, support faces, curves)
    /// without modifying the shape topology.
    /// - Parameters:
    ///   - edges: Edges to fillet.
    ///   - radius: Fillet radius.
    /// - Returns: Fillet surface result, or nil on failure.
    public func filletSurfaces(edges: [Shape], radius: Double) -> FilletSurfaceResult? {
        let edgeHandles = edges.map { $0.handle as OCCTShapeRef }
        var outSurfaces: UnsafeMutablePointer<OCCTFilletSurfInfo>?
        var outCount: Int32 = 0
        let status = edgeHandles.withUnsafeBufferPointer { buf in
            OCCTFilletSurfBuild(
                handle, buf.baseAddress!, Int32(edges.count), radius, &outSurfaces, &outCount)
        }
        if status == 1 && outCount == 0 { return nil }

        var infos: [FilletSurfaceInfo] = []
        if let outSurfaces {
            for i in 0..<Int(outCount) {
                let info = outSurfaces[i]
                guard let surfH = info.surface, let sf1 = info.supportFace1,
                    let sf2 = info.supportFace2
                else { continue }
                infos.append(
                    FilletSurfaceInfo(
                        surface: Surface(handle: surfH),
                        supportFace1: Shape(handle: sf1),
                        supportFace2: Shape(handle: sf2),
                        tolerance: info.tolerance,
                        firstParameter: info.firstParam,
                        lastParameter: info.lastParam,
                        startStatus: Int(info.startStatus),
                        endStatus: Int(info.endStatus)
                    ))
            }
            free(outSurfaces)
        }
        return FilletSurfaceResult(surfaces: infos, status: Int(status))
    }
    /// Create a rolling-ball blend on specified edges.
    ///
    /// `edgeIndices` are indices into ``edges()``, the same enumeration ``edge(at:)`` and
    /// ``Edge/index`` use, so a geometrically selected edge feeds straight in:
    ///
    /// ```swift
    /// let seams = part.edges { $0.length > 20 }
    /// let blended = part.biTgteBlend(edgeIndices: seams.map(\.index), radius: 2)
    /// ```
    ///
    /// The whole request is refused (`nil`) if any index names no edge, rather than blending the
    /// rest, a partial blend is not distinguishable from a complete one (#568).
    public func biTgteBlend(
        edgeIndices: [Int], radius: Double, tolerance: Double = 1e-3, nubs: Bool = false
    ) -> Shape? {
        let indices = edgeIndices.map { Int32($0) }
        guard
            let ref = indices.withUnsafeBufferPointer({ buf in
                OCCTBiTgteBlend(
                    handle, buf.baseAddress!, Int32(edgeIndices.count), radius, tolerance, nubs)
            })
        else { return nil }
        return Shape(handle: ref)
    }
    /// Create a preview box shape (handles degenerate dimensions: face, edge, vertex).
    public static func previewBox(width: Double, height: Double, depth: Double) -> Shape? {
        guard let ref = OCCTPreviewBox(width, height, depth) else { return nil }
        return Shape(handle: ref)
    }
    /// Create an evolved shape from a face spine and wire profile.
    public static func evolved(
        spineFace: Shape, profileWire: Shape,
        axisOrigin: SIMD3<Double> = SIMD3(0, 0, 0),
        axisNormal: SIMD3<Double> = SIMD3(0, 0, 1),
        axisXDir: SIMD3<Double> = SIMD3(1, 0, 0),
        joinType: Int = 0, makeSolid: Bool = false
    ) -> Shape? {
        guard
            let ref = OCCTBRepFillEvolved(
                spineFace.handle, profileWire.handle,
                axisOrigin.x, axisOrigin.y, axisOrigin.z,
                axisNormal.x, axisNormal.y, axisNormal.z,
                axisXDir.x, axisXDir.y, axisXDir.z,
                Int32(joinType), makeSolid)
        else { return nil }
        return Shape(handle: ref)
    }

    /// Boolean section with fuzzy tolerance.
    public func section(with other: Shape, tolerance: Double) -> Shape? {
        guard let ref = OCCTBooleanSectionWithTolerance(handle, other.handle, tolerance) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Split this shape by multiple tool shapes.
    public func split(tools: [Shape], tolerance: Double = 0) -> Shape? {
        let toolRefs = tools.map { $0.handle as OCCTShapeRef }
        guard
            let ref = toolRefs.withUnsafeBufferPointer({ buf in
                OCCTBooleanSplitMulti(handle, buf.baseAddress!, Int32(tools.count), tolerance)
            })
        else { return nil }
        return Shape(handle: ref)
    }

    /// Result of a boolean operation with history tracking.
    public struct BooleanHistoryResult: Sendable {
        public let shape: Shape
        public let hasDeleted: Bool
        public let hasModified: Bool
        public let hasGenerated: Bool
    }

    /// Boolean cut with history tracking.
    public func subtractedWithHistory(_ tool: Shape, tolerance: Double = 0) -> BooleanHistoryResult?
    {
        var hasDel = false
        var hasMod = false
        var hasGen = false
        guard
            let ref = OCCTBooleanCutWithHistory(
                handle, tool.handle, tolerance,
                &hasDel, &hasMod, &hasGen)
        else { return nil }
        return BooleanHistoryResult(
            shape: Shape(handle: ref),
            hasDeleted: hasDel, hasModified: hasMod, hasGenerated: hasGen)
    }

}

extension Shape {

    /// Restrict a face to its wires using BRepAlgo_FaceRestrictor.
    /// - Parameter faceIndex: Index of the face (0-based)
    /// - Returns: Number of result faces
    public func faceRestrictAlgo(faceIndex: Int) -> Int {
        Int(OCCTShapeFaceRestrictAlgo(handle, Int32(faceIndex), nil, 0))
    }
}

extension Shape {

    /// Build loops (wires) from edges on a face.
    /// - Returns: Number of result wires, or -1 on error
    public func buildLoops(faceIndex: Int) -> Int {
        Int(OCCTShapeBuildLoops(handle, Int32(faceIndex)))
    }
}

extension Shape {

    /// Apply a draft angle modification to a face.
    /// - Parameters:
    ///   - faceIndex: Index of the face to draft
    ///   - direction: Draft direction
    ///   - angle: Draft angle in radians
    ///   - neutralPlaneOrigin: Origin of the neutral plane
    ///   - neutralPlaneNormal: Normal of the neutral plane
    /// - Returns: Modified shape, or nil on failure
    public func draftModification(
        faceIndex: Int, direction: SIMD3<Double>, angle: Double,
        neutralPlaneOrigin: SIMD3<Double>,
        neutralPlaneNormal: SIMD3<Double>
    ) -> Shape? {
        guard
            let ref = OCCTShapeDraftModification(
                handle, Int32(faceIndex),
                direction.x, direction.y, direction.z, angle,
                neutralPlaneOrigin.x, neutralPlaneOrigin.y, neutralPlaneOrigin.z,
                neutralPlaneNormal.x, neutralPlaneNormal.y, neutralPlaneNormal.z)
        else {
            return nil
        }
        return Shape(handle: ref)
    }
}

extension Shape {

    /// Concavity classification for edges.
    public enum ConcavityType: Int, Sendable {
        case convex = 0
        case concave = 1
        case tangent = 2
        case freeBound = 3
        case other = 4
    }

    /// Analyze edge concavity for all edges. angle is the tangency threshold in radians.
    public func analyseEdgeConcavity(angle: Double = .pi / 6.0) -> [ConcavityType] {
        let count = Int(OCCTAnalyseEdgeConcavity(handle, angle, nil))
        guard count > 0 else { return [] }
        var types = [Int32](repeating: 0, count: count)
        _ = OCCTAnalyseEdgeConcavity(handle, angle, &types)
        return types.map { ConcavityType(rawValue: Int($0)) ?? .other }
    }

    /// Explode shape into groups of faces connected by edges of a given concavity type.
    public func analyseExplode(angle: Double = .pi / 6.0, type: ConcavityType) -> Shape? {
        guard let ref = OCCTAnalyseExplode(handle, angle, Int32(type.rawValue)) else { return nil }
        return Shape(handle: ref)
    }

    /// Count edges of a given concavity type on a specific face.
    public func analyseEdgesOnFace(_ face: Shape, angle: Double = .pi / 6.0, type: ConcavityType)
        -> Int
    {
        Int(OCCTAnalyseEdgesOnFace(handle, angle, face.handle, Int32(type.rawValue)))
    }

    /// Count ancestor faces for an edge in offset analysis.
    public func analyseAncestorCount(edge: Shape, angle: Double = .pi / 6.0) -> Int {
        Int(OCCTAnalyseAncestorCount(handle, angle, edge.handle))
    }

    /// Count tangent edges at a vertex along a given edge.
    public func analyseTangentEdgeCount(edge: Shape, vertex: Shape, angle: Double = .pi / 6.0)
        -> Int
    {
        Int(OCCTAnalyseTangentEdgeCount(handle, angle, edge.handle, vertex.handle))
    }
}

extension Shape {

    /// Fuse two shapes with fuzzy tolerance.
    ///
    /// - Note: Delegates to ``union(_:fuzzyValue:glue:timeout:)`` (#832), so this now carries the
    ///   same ``defaultBooleanTimeout`` (120s) watchdog and the same "negative tolerance is
    ///   ignored" contract as the canonical boolean family, neither of which this narrower,
    ///   pre-#202/#206 entry point had on its own. Same signature, same return type by default;
    ///   a caller whose fuzzy-tolerance boolean legitimately needs longer than 120s can pass
    ///   `timeout:` explicitly (`0`/negative = unbounded, matching the pre-#832 behavior), added
    ///   as an additional parameter with a default value, so this remains source-compatible
    ///   (review finding on PR #867).
    ///
    /// - Warning: This is a **behavior change for existing callers who don't pass `timeout:`**,
    ///   not just an addition. Before #832 this method had no time bound at all, a legitimately
    ///   slow fuse on a large/complex assembly would run to completion, however long that took.
    ///   Existing production code calling `shape.fused(with: other, tolerance: t)` with no
    ///   `timeout:` argument still compiles unchanged, but now silently gets `nil` after 120s
    ///   instead of the result it previously always returned, with no compiler warning and no
    ///   error thrown to distinguish "timed out" from any other failure. This is deliberate,
    ///   matching ``union(_:fuzzyValue:glue:timeout:)``'s own established default and closing the
    ///   #206 hang-risk class this narrower entry point lacked protection from, but a caller
    ///   upgrading past this change who relies on an operation that legitimately takes longer than
    ///   120s must now pass `timeout:` explicitly (`0`/negative = unbounded) to keep the old
    ///   behavior (PR #870 aggregate review).
    public func fused(
        with other: Shape, tolerance: Double,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        union(other, fuzzyValue: tolerance, timeout: timeout)
    }

    /// Cut another shape from this shape with fuzzy tolerance.
    ///
    /// - Note: Delegates to ``subtracting(_:fuzzyValue:glue:timeout:)`` (#832), see
    ///   ``fused(with:tolerance:timeout:)``'s doc comment for what changed underneath, including
    ///   the **Warning** there: an existing caller not passing `timeout:` now silently gets `nil`
    ///   after 120s instead of running unbounded, exactly as before.
    public func subtracted(
        _ other: Shape, tolerance: Double,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        subtracting(other, fuzzyValue: tolerance, timeout: timeout)
    }

    /// Common of two shapes with fuzzy tolerance.
    ///
    /// - Note: Delegates to ``intersection(_:fuzzyValue:glue:timeout:)`` (#832), see
    ///   ``fused(with:tolerance:timeout:)``'s doc comment for what changed underneath, including
    ///   the **Warning** there: an existing caller not passing `timeout:` now silently gets `nil`
    ///   after 120s instead of running unbounded, exactly as before.
    public func intersected(
        with other: Shape, tolerance: Double,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        intersection(other, fuzzyValue: tolerance, timeout: timeout)
    }

    /// Glue mode for boolean operations (`BOPAlgo_GlueEnum`).
    ///
    /// - Warning: This encodes the same `BOPAlgo_GlueEnum` choice as ``BooleanGlue``
    ///   (`Shape.swift`) but with **different raw values** (`shift=0, full=1, off=2` here vs.
    ///   `off=0, shift=1, full=2` there), a legacy artifact from before #202 introduced
    ///   `BooleanGlue`, not corrected since to avoid changing this type's `RawRepresentable`
    ///   contract. Kept as a separate declaration rather than a typealias for exactly that reason
    ///   (#832): the case *names* match, so unlike the differing-raw-value pair a typealias would
    ///   silently repoint a caller's `.rawValue`/`init(rawValue:)` use to the wrong number. Do not
    ///   conflate the two by raw value. New code should prefer `BooleanGlue` directly via
    ///   ``union(_:fuzzyValue:glue:timeout:)`` and friends; the three methods below map by case
    ///   name (never by raw value) when delegating to that family.
    public enum GlueMode: Int32, Sendable {
        case shift = 0
        case full = 1
        case off = 2

        /// Case-name mapping to ``Shape/BooleanGlue``.
        ///
        /// Deliberately not a raw-value cast, since the two enums' raw values disagree (see
        /// ``GlueMode``'s doc comment). `internal`, not `private`, so
        /// `Issue832BooleanDelegationTests` (`@testable import`) can assert the mapping directly
        /// rather than only through an OCCT result that may not observably depend on glue mode for
        /// simple, already-coincident geometry.
        var asBooleanGlue: BooleanGlue {
            switch self {
            case .shift: return .shift
            case .full: return .full
            case .off: return .off
            }
        }
    }

    /// Fuse two shapes with glue mode.
    ///
    /// - Note: Delegates to ``union(_:fuzzyValue:glue:timeout:)`` (#832), mapping ``GlueMode`` to
    ///   ``BooleanGlue`` by case name, see ``GlueMode``'s doc comment about the raw-value
    ///   mismatch between the two enums. Also carries ``defaultBooleanTimeout`` by default;
    ///   pass `timeout:` explicitly to override (`0`/negative = unbounded), see
    ///   ``fused(with:tolerance:timeout:)``'s doc comment, including the **Warning** there: an
    ///   existing caller not passing `timeout:` now silently gets `nil` after 120s instead of
    ///   running unbounded, exactly as before.
    public func fused(
        with other: Shape, glue: GlueMode,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        union(other, glue: glue.asBooleanGlue, timeout: timeout)
    }

    /// Cut another shape with glue mode.
    ///
    /// - Note: Delegates to ``subtracting(_:fuzzyValue:glue:timeout:)`` (#832), see
    ///   ``fused(with:glue:timeout:)``'s doc comment, including the **Warning** on
    ///   ``fused(with:tolerance:timeout:)``: an existing caller not passing `timeout:` now
    ///   silently gets `nil` after 120s instead of running unbounded, exactly as before.
    public func subtracted(
        _ other: Shape, glue: GlueMode,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        subtracting(other, glue: glue.asBooleanGlue, timeout: timeout)
    }

    /// Common of two shapes with glue mode.
    ///
    /// - Note: Delegates to ``intersection(_:fuzzyValue:glue:timeout:)`` (#832), see
    ///   ``fused(with:glue:timeout:)``'s doc comment, including the **Warning** on
    ///   ``fused(with:tolerance:timeout:)``: an existing caller not passing `timeout:` now
    ///   silently gets `nil` after 120s instead of running unbounded, exactly as before.
    public func intersected(
        with other: Shape, glue: GlueMode,
        timeout: Double = Shape.defaultBooleanTimeout
    ) -> Shape? {
        intersection(other, glue: glue.asBooleanGlue, timeout: timeout)
    }
}

extension Shape {

    /// Join type for offset operations.
    public enum OffsetJoinType: Int32, Sendable {
        case arc = 0
        case tangent = 1
        case intersection = 2
    }

    /// Offset a wire on a plane.
    public func offsetWireOnPlane(distance: Double, joinType: OffsetJoinType = .arc) -> Shape? {
        guard let ref = OCCTOffsetWireOnPlane(handle, distance, joinType.rawValue) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Offset a face.
    public func offsetFace(distance: Double, joinType: OffsetJoinType = .arc) -> Shape? {
        guard let ref = OCCTOffsetFace(handle, distance, joinType.rawValue) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Check shape validity for boolean operations (small edges, self-interference).
    public func isBooleanValid(testSmallEdges: Bool = true, testSelfInterference: Bool = true)
        -> Bool
    {
        OCCTShapeBooleanCheckSingle(handle, testSmallEdges, testSelfInterference)
    }

    /// Check if two shapes are valid for a boolean operation.
    ///
    /// Operation: 0=unknown, 1=common, 2=fuse, 3=cut, 4=section.
    public func isBooleanValidWith(
        _ other: Shape, operation: Int32 = 0,
        testSmallEdges: Bool = true,
        testSelfInterference: Bool = true
    ) -> Bool {
        OCCTShapeBooleanCheckPair(
            handle, other.handle, operation, testSmallEdges, testSelfInterference)
    }
}

extension Shape {
    /// Remove feature faces from a solid shape (e.g., fillets, holes).
    ///
    /// The canonical defeaturing call. `withoutFeatures(faces:)` is the same operation addressing
    /// its faces by index instead of by shape, and `defeaturedWithFullHistory(faces:)` is the same
    /// operation again with the removal history retained; all three run one shared
    /// `BRepAlgoAPI_Defeaturing` path in the bridge. `removeFeatures(faces:)` was a fourth spelling
    /// of this call, reaching the same algorithm one OCCT layer down, and is deprecated in favour
    /// of this one (#536).
    ///
    /// Returns `nil` when `faces` is empty, and when the operation itself fails, defeaturing
    /// cannot always reconnect the surrounding topology, so a `nil` here is an ordinary outcome,
    /// not necessarily a caller error.
    ///
    /// ## What may be named, and what must belong
    ///
    /// Each element of `faces` names faces rather than having to be one: a compound of faces, a
    /// shell, or this whole shape all name the faces they contain, and naming a carrier is the same
    /// request as naming the faces it holds. The rule every element must satisfy:
    ///
    /// > Every element must name at least one face, and every face it names must be a face of this
    /// > shape. Otherwise the whole call returns `nil` and nothing is removed.
    ///
    /// So a request that mixes this shape's faces with another shape's fails, as does one carrying
    /// an edge or a vertex, which name no face at all. Membership is by identity, not by geometry:
    /// the same face measured off an identically-built shape is foreign, while the same face
    /// reversed is not, orientation is not identity.
    ///
    /// Until #578 a foreign face was dropped from the request and the rest proceeded, which is
    /// OCCT's own documented rule ("those that do not belong will be ignored"). That answered a
    /// success, with no warning, on a shape still carrying the feature the caller asked to remove,
    /// indistinguishable from a real removal. The index-addressed ``Shape/withoutFeatures(faces:)``
    /// has failed the whole call on one bad index since #497; both spellings now agree.
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let filleted = box.filleted(radius: 2.0)!
    ///
    /// // The fillet added faces beyond the box's own six; remove one of them again.
    /// let filletFaces = Array(filleted.subShapes(ofType: .face).dropFirst(6).prefix(1))
    /// if let plain = filleted.defeature(faces: filletFaces) {
    ///     print(plain.volume ?? 0)   // back to 8000.0, the unfilleted box
    /// }
    ///
    /// // A face from somewhere else fails the request rather than being ignored.
    /// let elsewhere = Shape.box(width: 11, height: 11, depth: 11)!.subShapes(ofType: .face)[0]
    /// print(filleted.defeature(faces: filletFaces + [elsewhere]) == nil)   // true
    /// ```
    ///
    /// - Parameter faces: The faces to remove, each element either a face of this shape, or a
    ///   shape whose faces all belong to this shape.
    /// - Returns: The defeatured shape, or `nil` on failure, including when the request names a
    ///   face this shape does not have.
    public func defeature(faces: [Shape]) -> Shape? {
        let faceHandles = faces.map { $0.handle as OCCTShapeRef? }
        return faceHandles.withUnsafeBufferPointer { buf -> Shape? in
            guard let baseAddress = buf.baseAddress else { return nil }
            // Need to cast from UnsafePointer<OCCTShapeRef?> to UnsafePointer<OCCTShapeRef>
            let ptr = UnsafeRawPointer(baseAddress).assumingMemoryBound(to: OCCTShapeRef.self)
            guard let result = OCCTShapeDefeature(handle, ptr, Int32(faces.count)) else {
                return nil
            }
            return Shape(handle: result)
        }
    }
}

extension Shape.History {
    /// Merge another history into this one.
    public func merge(_ other: Shape.History) {
        OCCTHistoryMerge(historyRef, other.historyRef)
    }

    /// Replace a generated entry.
    public func replaceGenerated(initial: Shape, generated: Shape) {
        OCCTHistoryReplaceGenerated(historyRef, initial.handle, generated.handle)
    }

    /// Replace a modified entry.
    public func replaceModified(initial: Shape, modified: Shape) {
        OCCTHistoryReplaceModified(historyRef, initial.handle, modified.handle)
    }

    /// Get the shapes that the given initial shape was modified to.
    public func modifiedShapes(of initial: Shape) -> [Shape] {
        let maxCount: Int32 = 64
        var refs = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = refs.withUnsafeMutableBufferPointer { buf in
            OCCTHistoryGetModifiedShapes(historyRef, initial.handle, buf.baseAddress!, maxCount)
        }
        return (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = refs[i] else { return nil }
            return Shape(handle: ref)
        }
    }

    /// Get the shapes generated from the given initial shape.
    public func generatedShapes(of initial: Shape) -> [Shape] {
        let maxCount: Int32 = 64
        var refs = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = refs.withUnsafeMutableBufferPointer { buf in
            OCCTHistoryGetGeneratedShapes(historyRef, initial.handle, buf.baseAddress!, maxCount)
        }
        return (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = refs[i] else { return nil }
            return Shape(handle: ref)
        }
    }
}

extension Shape {
    /// Compute section between two shapes with approximation and pcurve options.
    public static func sectionWithOptions(
        _ shape1: Shape, _ shape2: Shape,
        approximation: Bool = false,
        computePCurve1: Bool = false,
        computePCurve2: Bool = false
    ) -> Shape? {
        guard
            let h = OCCTShapeSectionWithOptions(
                shape1.handle, shape2.handle,
                approximation, computePCurve1, computePCurve2)
        else { return nil }
        return Shape(handle: h)
    }

    /// Get the ancestor face on shape1 for a section edge.
    public static func sectionAncestorFaceOn1(
        _ shape1: Shape, _ shape2: Shape, edge: Shape,
        approximation: Bool = false,
        computePCurve1: Bool = false,
        computePCurve2: Bool = false
    ) -> Shape? {
        guard
            let h = OCCTSectionAncestorFaceOn1(
                shape1.handle, shape2.handle, edge.handle,
                approximation, computePCurve1, computePCurve2)
        else { return nil }
        return Shape(handle: h)
    }

    /// Get the ancestor face on shape2 for a section edge.
    public static func sectionAncestorFaceOn2(
        _ shape1: Shape, _ shape2: Shape, edge: Shape,
        approximation: Bool = false,
        computePCurve1: Bool = false,
        computePCurve2: Bool = false
    ) -> Shape? {
        guard
            let h = OCCTSectionAncestorFaceOn2(
                shape1.handle, shape2.handle, edge.handle,
                approximation, computePCurve1, computePCurve2)
        else { return nil }
        return Shape(handle: h)
    }
}
