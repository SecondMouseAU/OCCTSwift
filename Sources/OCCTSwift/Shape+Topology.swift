import Foundation
import simd
import OCCTBridge

extension Shape {


    /// Number of vertices (corners) in the shape.
    ///
    /// ``nbVertices`` was a second spelling of this same question, backed by a bare
    /// `TopExp_Explorer` occurrence walk instead of this deduplicated count, and is deprecated in
    /// favour of this one (#651).
    public var vertexCount: Int {
        Int(OCCTShapeGetVertexCount(handle))
    }

    /// Get all vertices (corner points) of the shape
    ///
    /// - Returns: Array of vertex positions
    public func vertices() -> [SIMD3<Double>] {
        let count = OCCTShapeGetVertexCount(handle)
        guard count > 0 else { return [] }

        var coords = [Double](repeating: 0, count: Int(count) * 3)
        let written = OCCTShapeGetVertices(handle, &coords)

        var result: [SIMD3<Double>] = []
        result.reserveCapacity(Int(written))

        for i in 0..<Int(written) {
            result.append(SIMD3<Double>(
                coords[i * 3],
                coords[i * 3 + 1],
                coords[i * 3 + 2]
            ))
        }
        return result
    }

    /// Get vertex at specific index
    ///
    /// - Parameter index: Zero-based vertex index
    /// - Returns: Vertex position, or nil if index out of bounds
    public func vertex(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTShapeGetVertexAt(handle, Int32(index), &x, &y, &z) else { return nil }
        return SIMD3<Double>(x, y, z)
    }

    /// A pair of face indices detected as near-miss (within tolerance)
    public struct FaceProximityPair: Sendable {
        public let face1Index: Int
        public let face2Index: Int
    }

    /// Detect face pairs between this shape and another that are within tolerance.
    /// - Parameter deflection: Linear mesh deflection (mm) for the proximity triangulation. Default `0.1`.
    public func proximityFaces(with other: Shape, tolerance: Double, deflection: Double = 0.1) -> [FaceProximityPair] {
        var buffer = [OCCTFaceProximityPair](repeating: OCCTFaceProximityPair(), count: 256)
        let count = OCCTShapeProximity(handle, other.handle, tolerance, &buffer, 256, deflection)

        var pairs = [FaceProximityPair]()
        for i in 0..<Int(count) {
            pairs.append(FaceProximityPair(
                face1Index: Int(buffer[i].face1Index),
                face2Index: Int(buffer[i].face2Index)
            ))
        }
        return pairs
    }

    /// Check if this shape self-intersects
    public var selfIntersects: Bool {
        OCCTShapeSelfIntersects(handle)
    }
    /// Replace a sub-shape within this shape.
    ///
    /// - Parameters:
    ///   - oldSubShape: The sub-shape to replace
    ///   - newSubShape: The replacement sub-shape
    /// - Returns: The modified shape, or nil on failure
    public func replacingSubShape(_ oldSubShape: Shape, with newSubShape: Shape) -> Shape? {
        guard let h = OCCTShapeReplaceSubShape(handle, oldSubShape.handle, newSubShape.handle)
        else { return nil }
        return Shape(handle: h)
    }

    /// Remove a sub-shape from this shape.
    ///
    /// - Parameter subShape: The sub-shape to remove
    /// - Returns: The modified shape, or nil on failure
    public func removingSubShape(_ subShape: Shape) -> Shape? {
        guard let h = OCCTShapeRemoveSubShape(handle, subShape.handle) else { return nil }
        return Shape(handle: h)
    }
    /// Make this shape periodic in one or more directions.
    ///
    /// - Parameters:
    ///   - xPeriod: Period in X (nil = not periodic in X)
    ///   - yPeriod: Period in Y (nil = not periodic in Y)
    ///   - zPeriod: Period in Z (nil = not periodic in Z)
    /// - Returns: A periodic shape, or nil on failure
    public func makePeriodic(xPeriod: Double? = nil,
                              yPeriod: Double? = nil,
                              zPeriod: Double? = nil) -> Shape? {
        guard let h = OCCTShapeMakePeriodic(
            handle,
            xPeriod != nil, xPeriod ?? 0,
            yPeriod != nil, yPeriod ?? 0,
            zPeriod != nil, zPeriod ?? 0
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Repeat this shape periodically in one or more directions.
    ///
    /// - Parameters:
    ///   - xPeriod: Period in X (nil = no repetition in X)
    ///   - yPeriod: Period in Y (nil = no repetition in Y)
    ///   - zPeriod: Period in Z (nil = no repetition in Z)
    ///   - xCount: Number of repetitions in X
    ///   - yCount: Number of repetitions in Y
    ///   - zCount: Number of repetitions in Z
    /// - Returns: The repeated shape, or nil on failure
    public func repeated(xPeriod: Double? = nil, xCount: Int = 0,
                          yPeriod: Double? = nil, yCount: Int = 0,
                          zPeriod: Double? = nil, zCount: Int = 0) -> Shape? {
        guard let h = OCCTShapeRepeat(
            handle,
            xPeriod != nil, xPeriod ?? 0,
            yPeriod != nil, yPeriod ?? 0,
            zPeriod != nil, zPeriod ?? 0,
            Int32(xCount), Int32(yCount), Int32(zCount)
        ) else { return nil }
        return Shape(handle: h)
    }
    /// Create a shell from a parametric surface.
    ///
    /// Converts a `Surface` to a topological shell shape.
    ///
    /// - Parameter surface: The parametric surface to convert
    /// - Returns: A shell shape, or nil on failure
    public static func shell(from surface: Surface) -> Shape? {
        guard let h = OCCTShapeCreateShellFromSurface(surface.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Create a vertex shape at a point.
    ///
    /// - Parameter point: The 3D point position
    /// - Returns: A vertex shape
    public static func vertex(at point: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateVertex(point.x, point.y, point.z) else { return nil }
        return Shape(handle: h)
    }
    /// Merge connected edges that lie on the same curve.
    ///
    /// Removes unnecessary edge splits introduced by boolean operations
    /// or other operations, simplifying the topology.
    ///
    /// - Returns: Shape with fused edges, or nil on failure
    public func fusedEdges() -> Shape? {
        guard let h = OCCTShapeFuseEdges(handle) else { return nil }
        return Shape(handle: h)
    }
    /// A census of sub-shape *occurrences* in this shape, from `ShapeAnalysis_ShapeContents`.
    ///
    /// This is a complexity metric, not the addressable sub-shape enumeration. It counts one
    /// entry per visit in the topology tree, so a sub-shape reachable from two parents is
    /// counted twice, and every edge of a box is counted once per adjacent face:
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.edgeCount)          // 12 — the distinct edges, and the addressable ones
    /// print(box.contents.edges)     // 24 — one per (face, edge) visit
    /// print(box.faceCount)          // 6
    /// print(box.contents.faces)     // 6 — a box shares no face, so these agree
    /// ```
    ///
    /// **None of these numbers is an index bound.** `0..<contents.faces` overruns
    /// ``face(at:)`` on any shape with a shared face; use ``faceCount``.
    ///
    /// There is a third count in play, and it is a third rule again:
    /// ``contentsExtended()``'s `nbSharedFaces` and friends deduplicate with the location
    /// *discarded*, so unlike ``faceCount`` — which follows `TopoDS_Shape::IsSame` and keeps
    /// placements apart — they also collapse two instances of one body. Measured on the pinned
    /// kernel (`Scripts/repro/541-face-index-contract/`), on a compound of a box with a
    /// ``moved(dx:dy:dz:)`` copy of itself: `faceCount` 12, `contents.faces` 12,
    /// `nbSharedFaces` 6. (``translated(by:)`` does not make an instance — it rebuilds through
    /// `BRepBuilderAPI_Transform`, so the copy shares nothing and all three read 12.)
    ///
    /// - Returns: Counts of solids, shells, faces, wires, edges, vertices, and free
    ///   (unconnected) elements.
    public var contents: ShapeContents {
        let core = ShapeContentsCore(OCCTShapeGetContents(handle))
        return ShapeContents(
            solids: core.solids, shells: core.shells,
            faces: core.faces, wires: core.wires,
            edges: core.edges, vertices: core.vertices,
            freeEdges: core.freeEdges, freeWires: core.freeWires,
            freeFaces: core.freeFaces
        )
    }
    /// Fix wireframe issues (small edges, gaps).
    ///
    /// - Parameter tolerance: Fixing tolerance
    /// - Returns: Shape with fixed wireframe, or nil on failure
    public func fixedWireframe(tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeFixWireframe(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
    /// Find pairs of edges that are coincident within tolerance.
    ///
    /// Useful for pre-sewing diagnostics to identify edges that
    /// could be merged.
    ///
    /// - Parameter tolerance: Contiguity tolerance
    /// - Returns: Number of contiguous edge pairs found
    public func contiguousEdgeCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTShapeFindContiguousEdges(handle, tolerance))
    }
    /// Quilt multiple shapes (faces/shells) together into a single shell.
    ///
    /// Joins faces that share common edges into a connected shell.
    ///
    /// - Parameter shapes: Array of shapes to quilt together
    /// - Returns: Quilted shell, or nil on failure
    public static func quilt(_ shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeQuilt(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
    /// Fix small faces by removing or merging them.
    ///
    /// - Parameter tolerance: Precision tolerance for identifying small faces
    /// - Returns: Shape with small faces fixed, or nil on failure
    public func fixingSmallFaces(tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeFixSmallFaces(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
    /// Create a face from a surface with specific UV parameter bounds.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface
    ///   - uRange: U parameter range (uMin, uMax)
    ///   - vRange: V parameter range (vMin, vMax)
    ///   - tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public static func face(from surface: Surface,
                            uRange: ClosedRange<Double>,
                            vRange: ClosedRange<Double>,
                            tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeCreateFaceFromSurface(surface.handle,
                                                      uRange.lowerBound, uRange.upperBound,
                                                      vRange.lowerBound, vRange.upperBound,
                                                      tolerance) else { return nil }
        return Shape(handle: h)
    }

    /// Create a face from a surface bounded by a **3D wire**, trimming the surface to the wire's
    /// footprint. Useful for reconstruction: trim a fitted analytic surface (cylinder / cone /
    /// sphere / B-spline) to a region's real boundary instead of a rectangular UV patch.
    ///
    /// Two strategies, tried in order:
    /// 1. If the wire genuinely lies on the surface (its edges have, or admit, pcurves), build the
    ///    face directly (`BRepBuilderAPI_MakeFace` + `ShapeFix_Face` to project pcurves) — exact.
    /// 2. Otherwise (e.g. a sampled boundary polyline whose straight chords don't lie on the
    ///    surface), project the wire's ordered points onto the surface's UV and trim by that
    ///    polygon — robust, the same path as ``Surface/toFace(uvBoundary:)``.
    ///
    /// If you already have the boundary in UV space, call ``Surface/toFace(uvBoundary:)`` directly.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface to trim.
    ///   - boundary: A closed wire on (or near) the surface.
    /// - Returns: The trimmed face, or nil on failure. Note: a boundary crossing a periodic seam
    ///   (e.g. the u = 0/2π seam of a cylinder) isn't handled by the projection fallback.
    public static func face(from surface: Surface, boundary: Wire) -> Shape? {
        // 1) Exact: the wire lies on the surface.
        if let h = OCCTShapeCreateFaceFromSurfaceWire(surface.handle, boundary.handle) {
            return Shape(handle: h)
        }
        // 2) Fallback: project the wire's ordered boundary points to UV and trim by that polygon.
        var uv: [SIMD2<Double>] = []
        for i in 0..<boundary.orderedEdgeCount {
            guard let pts = boundary.orderedEdgePoints(at: i) else { continue }
            for p in pts {
                guard let proj = surface.projectPoint(p) else { continue }
                let q = SIMD2(proj.u, proj.v)
                if let last = uv.last, simd_distance(last, q) < 1e-9 { continue }   // dedup shared vertices
                uv.append(q)
            }
        }
        if let f = uv.first, let l = uv.last, simd_distance(f, l) < 1e-9 { uv.removeLast() }
        guard uv.count >= 3 else { return nil }
        return surface.toFace(uvBoundary: uv)
    }

    /// Create a face from a surface trimmed by an **outer** wire with **interior hole** wires
    /// (windows / cutouts) — a single trimmed face with real openings.
    ///
    /// Wraps `BRepBuilderAPI_MakeFace(surface, outer)` then `.Add(hole)` per inner wire, then
    /// `ShapeFix_Face` to project pcurves onto the surface and orient the holes. Unlike the
    /// single-loop ``face(from:boundary:)``, this represents a panel whose surface has cutouts —
    /// e.g. a fitted B-spline carbody side panel with window/door openings, so the surface doesn't
    /// span (balloon over) the windows.
    ///
    /// All wires must lie on (or near) the surface — typically a fitted analytic / B-spline surface
    /// and the region's real boundary loops. The inner wires are interior loops fully inside `outer`.
    ///
    /// ```swift
    /// // Trim a fitted panel surface to its outline, with two window cutouts:
    /// let panel = Shape.face(from: fittedSurface, outer: outline, innerWires: [window1, window2])
    /// ```
    ///
    /// - Parameters:
    ///   - surface: The parametric surface to trim.
    ///   - outer: The closed outer boundary wire on (or near) the surface.
    ///   - innerWires: Closed interior loops (holes) on the surface; empty gives a plain trimmed face.
    /// - Returns: The trimmed face-with-holes, or nil on failure (e.g. a wire off the surface, a
    ///   self-intersecting loop, or a hole not enclosed by `outer`).
    public static func face(from surface: Surface, outer: Wire, innerWires: [Wire]) -> Shape? {
        let handles: [OCCTWireRef?] = innerWires.map { $0.handle }
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateFaceFromSurfaceWireWithHoles(surface.handle, outer.handle,
                                                        buffer.baseAddress, Int32(innerWires.count))
        }) else { return nil }
        return Shape(handle: handle)
    }
    /// Reconstruct faces from a compound of loose edges.
    ///
    /// Takes a shape containing edges and tries to build closed wires,
    /// then creates faces from those wires.
    ///
    /// - Parameters:
    ///   - compound: Shape containing edges to assemble into faces
    ///   - onlyPlanar: If true, only create planar faces
    /// - Returns: Compound of faces, or nil on failure
    public static func facesFromEdges(_ compound: Shape, onlyPlanar: Bool = true) -> Shape? {
        guard let h = OCCTShapeEdgesToFaces(compound.handle, onlyPlanar) else { return nil }
        return Shape(handle: h)
    }
    /// Remove degenerate/tiny edges from a shape.
    ///
    /// Useful for cleaning up imported geometry with tolerance issues.
    ///
    /// Equivalent to `fixSmallEdges(tolerance:dropSmall: true)` — both build a
    /// `ShapeFix_Wireframe` with the same precision/drop-mode/perform sequence. The two used to
    /// default to different tolerances (`1e-6` here vs `1e-7` there) for the identical underlying
    /// call; aligned to `1e-7` (#839), matching `fixSmallEdges` and its sibling `fixWireGaps`, so
    /// an edge near that boundary is no longer dropped by one and kept by the other depending
    /// only on which of the two near-identical entry points was called.
    ///
    /// - Parameter tolerance: Tolerance below which edges are considered small
    /// - Returns: Shape with small edges removed, or nil on failure
    public func droppingSmallEdges(tolerance: Double = 1e-7) -> Shape? {
        guard let h = OCCTShapeDropSmallEdges(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
    /// Create a shell from a parametric surface with UV bounds.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface
    ///   - uRange: U parameter range
    ///   - vRange: V parameter range
    /// - Returns: Shell shape, or nil on failure
    public static func shell(from surface: Surface,
                             uRange: ClosedRange<Double>,
                             vRange: ClosedRange<Double>) -> Shape? {
        guard let h = OCCTShapeMakeShell(surface.handle,
                                          uRange.lowerBound, uRange.upperBound,
                                          vRange.lowerBound, vRange.upperBound) else { return nil }
        return Shape(handle: h)
    }
    /// Create a deep, independent copy of this shape.
    ///
    /// Backed by `BRepBuilderAPI_Copy`. When `copyGeometry`/`copyMesh` are `true`, this clones the
    /// actual `Geom_Surface`/`Geom_Curve`/`Poly_Triangulation` objects, not just topology — unlike
    /// the no-argument instance ``deepCopy()``, which never clones geometry regardless of these
    /// flags. See `docs/thread-safety.md` for why that distinction matters for concurrent use.
    ///
    /// - Parameters:
    ///   - copyGeometry: If true, copy the underlying geometry (default: true).
    ///   - copyMesh: If true, also copy mesh data (default: false).
    /// - Returns: A new independent shape, or nil on failure.
    public func copy(copyGeometry: Bool = true, copyMesh: Bool = false) -> Shape? {
        guard let h = OCCTShapeCopy(handle, copyGeometry, copyMesh) else { return nil }
        return Shape(handle: h)
    }
    /// Number of solid sub-shapes.
    ///
    /// A named spelling of `subShapeCount(ofType: .solid)`, reading the same enumeration, so
    /// "distinct solid" means what it does there: one body reachable from two parents counts once,
    /// two *placements* of it count twice. (#502)
    ///
    /// ```swift
    /// let a = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(origin: SIMD3(50, 0, 0), width: 10, height: 10, depth: 10)!
    /// print(Shape.compound([a, b])!.solidCount)   // 2
    /// print(a.solidCount)                         // 1, a solid is its own sub-shape
    /// ```
    public var solidCount: Int { subShapeCount(ofType: .solid) }

    /// Extract all solid sub-shapes, in enumeration order.
    ///
    /// ```swift
    /// let part = Shape.compound([
    ///     Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!,
    ///     Shape.box(origin: SIMD3(50, 0, 0), width: 4, height: 4, depth: 4)!,
    /// ])!
    /// print(part.solids.count)                       // 2
    /// print(part.solids.map(\.volume))               // [1000.0, 64.0]
    /// ```
    public var solids: [Shape] { subShapes(ofType: .solid) }

    /// Number of shell sub-shapes.
    ///
    /// A named spelling of `subShapeCount(ofType: .shell)`. A shell reused by two solids (the
    /// shape `solidFromShells` produces when handed the same shell twice) is one shell. (#502)
    ///
    /// ```swift
    /// let hollow = Shape.box(origin: .zero, width: 20, height: 20, depth: 20)!
    ///     .subtracting(Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8)!)!
    /// print(hollow.shellCount)   // 2, the outer boundary and the cavity
    /// ```
    public var shellCount: Int { subShapeCount(ofType: .shell) }

    /// The **outer shell** of this solid (`BRepClass3d::OuterShell`).
    ///
    /// For a solid with internal voids (multiple shells — e.g. a body with a cavity), this
    /// returns the shell that bounds the outer body, distinguishing it from the inner void
    /// shells. Useful for decomposing a part into outer-body + cavities.
    ///
    /// Returns `nil` unless this shape denotes exactly **one** solid — i.e. it is a solid, or a
    /// compound/compsolid wrapping a single solid. A container holding two or more solids has no
    /// single outer shell to name, so it gets `nil` rather than one arbitrary member's shell;
    /// use ``outerShells`` for those. (#211, #439)
    ///
    /// ```swift
    /// let hollow = Shape.box(width: 20, height: 20, depth: 20)!
    ///     .subtracting(Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8)!)!
    /// print(hollow.outerShell?.faceCount ?? -1)     // 6 — the 20-cube's boundary
    /// print(hollow.innerShells.count)               // 1 — the cavity
    ///
    /// // Two bodies in one compound: nil, not the first body's shell.
    /// let a = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
    /// print(Shape.compound([a, b])!.outerShell == nil)   // true
    /// ```
    public var outerShell: Shape? {
        OCCTShapeOuterShell(handle).map(Shape.init(handle:))
    }

    /// The **outer shell of every solid** in this shape, in exploration order.
    ///
    /// The multi-body counterpart of ``outerShell``: one shell per solid, so a compound of two
    /// bodies yields two shells. Empty for a shape with no solids. Equivalent to
    /// `solids.compactMap(\.outerShell)`, in a single traversal.
    ///
    /// Note that these shells drop internal void walls by design (that is what an *outer* shell
    /// is). To measure against the complete boundary of a multi-body part — cavities included —
    /// use `Shape.compound(subShapes(ofType: .face))` instead. (#439)
    ///
    /// ```swift
    /// let a = Shape.box(origin: .zero, width: 10, height: 10, depth: 10)!
    /// let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)!
    /// let part = Shape.compound([a, b])!
    /// print(part.outerShells.count)                    // 2
    /// print(part.outerShells.map(\.faceCount))         // [6, 6]
    /// ```
    public var outerShells: [Shape] {
        let count = OCCTShapeOuterShells(handle, nil, 0)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeOuterShells(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in h.map { Shape(handle: $0) } }
    }

    /// The **inner** (void / cavity) shells of this solid — every shell except ``outerShell``.
    ///
    /// Empty for a solid with no internal voids, and — following the same single-solid rule as
    /// ``outerShell`` — for a non-solid or a container holding two or more solids. Pairs with
    /// ``outerShell`` to decompose a part into outer body + cavities; for a multi-body part,
    /// take each solid separately (`solids.flatMap(\.innerShells)`). (#212, #439)
    ///
    /// ```swift
    /// let block = Shape.box(width: 20, height: 20, depth: 20)!
    /// let cavity = Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8)!
    /// let hollow = block.subtracting(cavity)!
    /// print(hollow.innerShells.count)      // 1
    /// ```
    public var innerShells: [Shape] {
        let count = OCCTShapeInnerShells(handle, nil, 0)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeInnerShells(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in h.map { Shape(handle: $0) } }
    }

    /// Extract all shell sub-shapes, in enumeration order.
    ///
    /// ```swift
    /// let hollow = Shape.box(origin: .zero, width: 20, height: 20, depth: 20)!
    ///     .subtracting(Shape.box(origin: SIMD3(6, 6, 6), width: 8, height: 8, depth: 8)!)!
    /// print(hollow.shells.count)   // 2
    /// ```
    ///
    /// To tell the boundary from the cavities, use ``outerShell`` / ``innerShells`` instead;
    /// this is the plain enumeration and puts no meaning on the order.
    public var shells: [Shape] { subShapes(ofType: .shell) }

    /// Number of wire sub-shapes.
    ///
    /// A named spelling of `subShapeCount(ofType: .wire)`. A wire used to build two faces counts
    /// once, since it is one wire seen from two parents. (#502)
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 5, depth: 3)!
    /// print(box.wireCount)   // 6, one boundary wire per face
    /// ```
    public var wireCount: Int { subShapeCount(ofType: .wire) }

    /// Extract all wire sub-shapes, in enumeration order.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 5, depth: 3)!
    /// print(box.wires.count)                       // 6
    /// print(box.wires.compactMap(Wire.init).count)  // 6, as typed Wire objects
    /// ```
    public var wires: [Shape] { subShapes(ofType: .wire) }

    // MARK: - Shape Surgery (v0.41.0)

    /// Remove sub-shapes from this shape
    ///
    /// Uses BRepTools_ReShape to surgically remove faces, edges, or vertices
    /// while preserving the remaining topology.
    /// - Parameter subShapes: Sub-shapes to remove
    /// - Returns: Shape with sub-shapes removed, or nil on failure
    public func removingSubShapes(_ subShapes: [Shape]) -> Shape? {
        var handles = subShapes.map { $0.handle as OCCTShapeRef? }
        guard let h = handles.withUnsafeMutableBufferPointer({ buf in
            OCCTShapeRemoveSubShapes(handle, buf.baseAddress, Int32(subShapes.count))
        }) else { return nil }
        return Shape(handle: h)
    }

    /// Replace sub-shapes in this shape
    ///
    /// Uses BRepTools_ReShape to replace specific sub-shapes with new ones.
    /// - Parameter replacements: Array of (old, new) shape pairs
    /// - Returns: Shape with replacements applied, or nil on failure
    public func replacingSubShapes(_ replacements: [(old: Shape, new: Shape)]) -> Shape? {
        var oldHandles = replacements.map { $0.old.handle as OCCTShapeRef? }
        var newHandles = replacements.map { $0.new.handle as OCCTShapeRef? }
        guard let h = oldHandles.withUnsafeMutableBufferPointer({ oldBuf in
            newHandles.withUnsafeMutableBufferPointer({ newBuf in
                OCCTShapeReplaceSubShapes(handle, oldBuf.baseAddress, newBuf.baseAddress,
                                           Int32(replacements.count))
            })
        }) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Face Restriction (v0.41.0)

    /// Create restricted faces from a face and wire boundaries
    ///
    /// Uses BRepAlgo_FaceRestrictor to build faces on the underlying surface
    /// of this shape's first face, bounded by the given wires.
    /// - Parameter boundaries: Wire boundaries that define the restricted regions
    /// - Returns: Array of restricted face shapes, or nil on failure
    public func faceRestricted(by boundaries: [Wire]) -> [Shape]? {
        let maxFaces: Int32 = 64
        var wireHandles = boundaries.map { $0.handle as OCCTWireRef? }
        var outFaces = [OCCTShapeRef?](repeating: nil, count: Int(maxFaces))

        let count = wireHandles.withUnsafeMutableBufferPointer { wireBuf in
            outFaces.withUnsafeMutableBufferPointer { faceBuf in
                OCCTShapeFaceRestrict(handle, wireBuf.baseAddress, Int32(boundaries.count),
                                       faceBuf.baseAddress, maxFaces)
            }
        }
        guard count > 0 else { return nil }
        return (0..<Int(count)).compactMap { i in
            guard let ref = outFaces[i] else { return nil }
            return Shape(handle: ref)
        }
    }

    // MARK: - v0.42.0: Solid Construction, 2D Fillet/Chamfer, Point Cloud Analysis

    /// Create a solid from one or more shell shapes.
    ///
    /// Uses BRepBuilderAPI_MakeSolid to construct a solid from shells extracted from
    /// the given shapes. The first shape provides the outer shell, and additional shapes
    /// provide cavity (inner) shells.
    ///
    /// - Note: Each element contributes only the **first** shell found in it, so pass one
    ///   shape per shell rather than a compound of several. An element holding no shell is
    ///   skipped silently, except the first, which fails the whole call.
    ///
    /// - Parameter shells: Array of shapes containing shells (first = outer, rest = cavities)
    /// - Returns: Solid shape, or nil on failure
    public static func solidFromShells(_ shells: [Shape]) -> Shape? {
        guard !shells.isEmpty else { return nil }
        var handles = shells.map { $0.handle as OCCTShapeRef? }
        let result = handles.withUnsafeMutableBufferPointer { buffer in
            OCCTSolidFromShells(buffer.baseAddress, Int32(shells.count))
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    // MARK: - v0.43.0: Face Subdivision, Small Face Detection, Location Purge

    /// Subdivide faces whose area exceeds a maximum threshold.
    ///
    /// Uses ShapeUpgrade_ShapeDivideArea to split faces larger than the specified area.
    /// Useful for mesh quality control and FEA preprocessing.
    ///
    /// - Parameter maxArea: Maximum face area — faces larger than this are split
    /// - Returns: Shape with subdivided faces, or nil on failure
    public func dividedByArea(maxArea: Double) -> Shape? {
        guard let ref = OCCTShapeDivideByArea(handle, maxArea) else { return nil }
        return Shape(handle: ref)
    }

    /// Subdivide faces into a target number of parts.
    ///
    /// Uses ShapeUpgrade_ShapeDivideArea in splitting-by-number mode.
    ///
    /// - Parameter parts: Target number of parts per face
    /// - Returns: Shape with subdivided faces, or nil on failure
    public func dividedByParts(_ parts: Int) -> Shape? {
        guard let ref = OCCTShapeDivideByParts(handle, Int32(parts)) else { return nil }
        return Shape(handle: ref)
    }

    /// Result of small/degenerate face analysis.
    public struct SmallFaceInfo: Sendable {
        /// Whether the face is collapsed to a point
        public let isSpotFace: Bool
        /// Whether the face has negligible width
        public let isStripFace: Bool
        /// Whether the face is twisted
        public let isTwisted: Bool
        /// Location of spot face (if isSpotFace is true)
        public let spotLocation: SIMD3<Double>?
    }

    /// Check faces for degenerate conditions (spot, strip, twisted).
    ///
    /// Uses ShapeAnalysis_CheckSmallFace to analyze each face of the shape.
    /// Returns only faces that have at least one degenerate condition.
    ///
    /// - Parameter tolerance: Analysis tolerance (default 1e-6)
    /// - Returns: Array of degenerate face descriptions, empty if none found
    public func checkSmallFaces(tolerance: Double = 1e-6) -> [SmallFaceInfo] {
        let maxResults: Int32 = 256
        var results = [OCCTSmallFaceResult](repeating: OCCTSmallFaceResult(), count: Int(maxResults))
        let count = results.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeCheckSmallFaces(handle, tolerance, buffer.baseAddress, maxResults)
        }
        return (0..<Int(count)).map { i in
            let r = results[i]
            return SmallFaceInfo(
                isSpotFace: r.isSpotFace,
                isStripFace: r.isStripFace,
                isTwisted: r.isTwisted,
                spotLocation: r.isSpotFace ? SIMD3(r.spotX, r.spotY, r.spotZ) : nil
            )
        }
    }

    // MARK: - Edge Connection

    /// Connect edges by merging shared vertices in the shape.
    ///
    /// Uses ShapeFix_EdgeConnect to identify edges that share geometric positions
    /// and merges their vertices. Useful for healing imported geometry where
    /// topologically disconnected edges actually meet at the same point.
    ///
    /// - Returns: Shape with connected edges, or nil on failure
    public var connectedEdges: Shape? {
        guard let ref = OCCTShapeConnectEdges(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Edge Concavity Analysis (v0.46.0)

    /// Edge concavity type from BRepOffset_Analyse
    public enum EdgeConcavity: Sendable {
        /// Edge connects two faces at a convex angle (outer edge of a box)
        case convex
        /// Edge connects two faces at a concave angle (inner edge of a groove)
        case concave
        /// Edge connects two faces that are tangent (smooth transition)
        case tangent
    }

    /// Classify all edges by their concavity type using `BRepOffset_Analyse`.
    ///
    /// Analyzes the angles between adjacent faces at each edge to determine
    /// whether each edge is convex, concave, or tangent.
    ///
    /// One entry per distinct edge, in ``edges()`` order — so `result[n].0.index == n`, and the
    /// classification at position `n` describes `edges()[n]`:
    ///
    /// ```swift
    /// for (edge, kind) in bracket.edgeConcavities() ?? [] where kind == .concave {
    ///     print("inside corner at edge \(edge.index), length \(edge.length)")
    /// }
    /// ```
    ///
    /// - Parameter angle: Threshold angle for tangent classification (radians, default 0.01)
    /// - Returns: Array of (edge, concavity) pairs, or nil on error
    public func edgeConcavities(angle: Double = 0.01) -> [(Edge, EdgeConcavity)]? {
        let count = edgeCount
        guard count > 0 else { return nil }

        var outTypes = [OCCTEdgeConcavity](repeating: OCCTEdgeConcavity(type: OCCTConcavityConvex),
                                            count: count)
        let classified = OCCTShapeAnalyzeEdgeConcavity(handle, angle, &outTypes, Int32(count))
        guard classified > 0 else { return nil }

        var result = [(Edge, EdgeConcavity)]()
        result.reserveCapacity(Int(classified))

        let allEdges = edges()
        for i in 0..<min(Int(classified), allEdges.count) {
            let concavity: EdgeConcavity
            switch outTypes[i].type {
            case OCCTConcavityConvex: concavity = .convex
            case OCCTConcavityConcave: concavity = .concave
            case OCCTConcavityTangent: concavity = .tangent
            default: concavity = .tangent
            }
            result.append((allEdges[i], concavity))
        }
        return result
    }

    /// Count edges of a specific concavity type.
    ///
    /// Counts distinct edges, so the three type counts sum to at most ``edgeCount`` — before #613
    /// this counted topology *occurrences* and a 12-edge box reported 24 convex edges.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// box.edgeConcavityCount(.convex)   // 12, matching box.edgeCount
    /// ```
    ///
    /// - Parameters:
    ///   - type: Concavity type to count
    ///   - angle: Threshold angle for tangent classification (radians, default 0.01)
    /// - Returns: Number of edges of the specified type, or nil on error
    public func edgeConcavityCount(_ type: EdgeConcavity, angle: Double = 0.01) -> Int? {
        let typeValue: Int32
        switch type {
        case .convex: typeValue = 0
        case .concave: typeValue = 1
        case .tangent: typeValue = 2
        }
        let count = OCCTShapeCountEdgeConcavity(handle, angle, typeValue)
        return count >= 0 ? Int(count) : nil
    }

    // MARK: - Geometric Edge Selection (v1.2.1)

    /// Select edges of this shape that satisfy a geometric predicate.
    ///
    /// This is the robust alternative to picking edges by raw index from
    /// ``edges()`` — the index shifts as soon as the model parameters change,
    /// whereas a geometric predicate keeps selecting the right edge. The returned
    /// edges carry their parent index, so they feed straight into
    /// ``filleted(edges:radius:)`` / ``chamferedTwoDistances(_:)`` etc.
    ///
    /// ```swift
    /// // Round only the long edges (> 50 mm) of a bracket
    /// let rounded = bracket.filleted(edges: bracket.edges { $0.length > 50 }, radius: 2)
    /// ```
    ///
    /// - Parameter predicate: Returns true for edges to keep.
    /// - Returns: The matching edges (possibly empty), each with a valid index.
    public func edges(where predicate: (Edge) -> Bool) -> [Edge] {
        edges().filter(predicate)
    }

    /// The concave edges of this solid (interior angle > 180°, e.g. the inside
    /// corner of an L-bracket or the bottom of a groove).
    ///
    /// These are the edges you usually want to *fillet* — a concave fillet adds
    /// material to soften an inside corner. Selecting them geometrically avoids the
    /// fragile "iterate `edges()` and guess the index" workaround.
    ///
    /// ```swift
    /// let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
    /// ```
    ///
    /// - Parameter angle: Threshold (radians) below which an edge counts as tangent
    ///   rather than concave (default 0.01).
    /// - Returns: The concave edges, or an empty array if none / on error.
    public func concaveEdges(angle: Double = 0.01) -> [Edge] {
        (edgeConcavities(angle: angle) ?? []).compactMap { $0.1 == .concave ? $0.0 : nil }
    }

    /// The convex edges of this solid (interior angle < 180°, e.g. the outer
    /// corners of a box).
    ///
    /// These are the edges you usually want to *chamfer* or round on the outside of
    /// a part.
    ///
    /// - Parameter angle: Threshold (radians) below which an edge counts as tangent
    ///   rather than convex (default 0.01).
    /// - Returns: The convex edges, or an empty array if none / on error.
    public func convexEdges(angle: Double = 0.01) -> [Edge] {
        (edgeConcavities(angle: angle) ?? []).compactMap { $0.1 == .convex ? $0.0 : nil }
    }

    /// Select straight edges whose direction is parallel to the given axis.
    ///
    /// Only line edges are considered (curved edges have no single direction). The
    /// test is sign-agnostic: an edge pointing along `+axis` or `-axis` both match.
    ///
    /// ```swift
    /// // Round every vertical edge of an extruded prism
    /// let rounded = part.filleted(edges: part.edges(parallelTo: SIMD3(0, 0, 1)), radius: 2)
    /// ```
    ///
    /// - Parameters:
    ///   - axis: The reference direction (need not be unit length).
    ///   - tolerance: Maximum sine of the angle between edge and axis (default 1e-4).
    /// - Returns: The matching straight edges, each with a valid index.
    public func edges(parallelTo axis: SIMD3<Double>, tolerance: Double = 1e-4) -> [Edge] {
        let axisLen = simd_length(axis)
        guard axisLen > 0 else { return [] }
        let a = axis / axisLen
        return edges().filter { edge in
            guard edge.isLine else { return false }
            let (start, end) = edge.endpoints
            let d = end - start
            let len = simd_length(d)
            guard len > 0 else { return false }
            // |cross| = sin(theta) for unit vectors; parallel when ~0.
            return simd_length(simd_cross(d / len, a)) <= tolerance
        }
    }

    /// Select edges fully contained within an axis-aligned bounding region.
    ///
    /// An edge matches when its entire bounding box lies inside the box spanned by
    /// `min`...`max` (inclusive). Useful for fillets that should only touch a
    /// localised region of an already-built solid.
    ///
    /// - Parameters:
    ///   - min: The lower corner of the region.
    ///   - max: The upper corner of the region.
    /// - Returns: The contained edges, each with a valid index.
    public func edges(inBounds min: SIMD3<Double>, _ max: SIMD3<Double>) -> [Edge] {
        let lo = simd_min(min, max)
        let hi = simd_max(min, max)
        return edges().filter { edge in
            let b = edge.bounds
            return all(b.min .>= lo) && all(b.max .<= hi)
        }
    }
    /// Shape check error status codes
    public enum CheckStatus: Int32, Sendable, CaseIterable {
        case noError = 0
        case invalidPointOnCurve = 1
        case invalidPointOnCurveOnSurface = 2
        case invalidPointOnSurface = 3
        case no3DCurve = 4
        case multiple3DCurve = 5
        case invalid3DCurve = 6
        case noCurveOnSurface = 7
        case invalidCurveOnSurface = 8
        case invalidCurveOnClosedSurface = 9
        case invalidSameRangeFlag = 10
        case invalidSameParameterFlag = 11
        case invalidDegeneratedFlag = 12
        case freeEdge = 13
        case invalidMultiConnexity = 14
        case invalidRange = 15
        case emptyWire = 16
        case redundantEdge = 17
        case selfIntersectingWire = 18
        case noSurface = 19
        case invalidWire = 20
        case redundantWire = 21
        case intersectingWires = 22
        case invalidImbricationOfWires = 23
        case emptyShell = 24
        case redundantFace = 25
        case invalidImbricationOfShells = 26
        case unorientableShape = 27
        case notClosed = 28
        case notConnected = 29
        case subshapeNotInShape = 30
        case badOrientation = 31
        case badOrientationOfSubshape = 32
        case invalidPolygonOnTriangulation = 33
        case invalidToleranceValue = 34
        case enclosedRegion = 35
        case checkFail = 36
    }

    /// Result of a shape validity check
    public struct CheckResult: Sendable {
        /// Whether the shape is valid (no errors)
        public let isValid: Bool
        /// Number of errors found
        public let errorCount: Int
        /// First error status (if any)
        public let firstError: CheckStatus?
    }

    /// Check the overall validity of this shape.
    ///
    /// Uses BRepCheck_Analyzer for comprehensive topology and geometry validation.
    ///
    /// - Returns: Check result with validity status and error details
    public var checkResult: CheckResult {
        let result = OCCTCheckShape(handle)
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Get detailed error status codes for this shape.
    ///
    /// Returns all individual error codes found during validation,
    /// useful for diagnosing exactly what's wrong with an invalid shape.
    ///
    /// - Returns: Array of check status codes
    public var detailedCheckStatuses: [CheckStatus] {
        var buffer = [OCCTCheckStatus](repeating: .init(rawValue: 0), count: 256)
        let count = OCCTCheckShapeDetailed(handle, &buffer, 256)
        guard count > 0 else { return [] }
        return (0..<Int(count)).compactMap { i in
            CheckStatus(rawValue: Int32(buffer[i].rawValue))
        }
    }

    // MARK: - LocOpe_FindEdges

    /// Find edges in common between this shape and another.
    ///
    /// Uses `LocOpe_FindEdges` to identify shared edges. The returned edges belong to **this**
    /// shape, and each carries its ``Edge/index`` into ``edges()`` — so a found edge feeds straight
    /// into ``filleted(edges:radius:)`` and every other index-taking method.
    ///
    /// ```swift
    /// // Round the seam where two halves of a split block meet
    /// let seam = lower.commonEdges(with: upper)
    /// let rounded = lower.filleted(edges: seam, radius: 1)
    /// ```
    ///
    /// The finder reports one entry per matched pair, so a single edge of this shape can appear
    /// more than once when it matches several edges of `other`. Dedupe on ``Edge/index`` if you
    /// need one entry per distinct edge.
    ///
    /// - Parameter other: Shape to compare with
    /// - Returns: Array of common edges, each with a valid index into ``edges()``.
    public func commonEdges(with other: Shape) -> [Edge] {
        var buffer = [OCCTShapeRef?](repeating: nil, count: 100)
        // #613: the bridge reports each found edge's index in THIS shape's enumeration. The array
        // position used to be written into Edge.index, which named a different edge or none at all.
        var indices = [Int32](repeating: -1, count: 100)
        let count = OCCTLocOpeFindEdges(handle, other.handle, &buffer, &indices, 100)
        var edges = [Edge]()
        edges.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = buffer[i] {
                // Convert shape to edge
                if let edgeRef = OCCTShapeGetEdgeAtIndex(ref, 0) {
                    edges.append(Edge(handle: edgeRef, index: Int(indices[i])))
                }
                OCCTShapeRelease(ref)
            }
        }
        return edges
    }

    // MARK: - LocOpe_FindEdgesInFace

    /// Find edges of this shape that lie in a specific face.
    ///
    /// Uses `LocOpe_FindEdgesInFace`. Each returned edge carries its ``Edge/index`` into
    /// ``edges()``, so it can be handed to any index-taking method:
    ///
    /// ```swift
    /// let onTop = block.edgesInFace(at: 3)
    /// let rounded = block.filleted(edges: onTop, radius: 2)
    ///
    /// // The index addresses the same edge through either route
    /// let e = onTop[0]
    /// block.edge(at: e.index)   // the very same edge
    /// ```
    ///
    /// - Parameter faceIndex: Index of the face to check, in the ``faces()`` enumeration (0-based)
    /// - Returns: Array of edges found in the face, each with a valid index into ``edges()``.
    public func edgesInFace(at faceIndex: Int) -> [Edge] {
        var buffer = [OCCTShapeRef?](repeating: nil, count: 100)
        // #613: as for commonEdges(with:) — the index comes from the shape's own enumeration, not
        // from this result array's ordering.
        var indices = [Int32](repeating: -1, count: 100)
        let count = OCCTLocOpeFindEdgesInFace(handle, Int32(faceIndex), &buffer, &indices, 100)
        var edges = [Edge]()
        edges.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = buffer[i] {
                if let edgeRef = OCCTShapeGetEdgeAtIndex(ref, 0) {
                    edges.append(Edge(handle: edgeRef, index: Int(indices[i])))
                }
                OCCTShapeRelease(ref)
            }
        }
        return edges
    }

    /// Check if a specific sub-shape is valid within this shape's context.
    ///
    /// - Parameters:
    ///   - type: Type of sub-shape to check
    ///   - index: 0-based index of the sub-shape
    /// - Returns: true if the sub-shape is valid
    public func isSubShapeValid(type: ShapeType, at index: Int) -> Bool {
        OCCTBRepCheckSubShapeValid(handle, Int32(type.rawValue), Int32(index))
    }

    // MARK: - BRepCheck per sub-shape type

    /// Check validity of an edge by index.
    public func checkEdge(at index: Int) -> CheckResult {
        let result = OCCTCheckEdge(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Check validity of a wire by index.
    public func checkWire(at index: Int) -> CheckResult {
        let result = OCCTCheckWire(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Check validity of a shell by index.
    public func checkShell(at index: Int) -> CheckResult {
        let result = OCCTCheckShell(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    /// Check validity of a vertex by index.
    public func checkVertex(at index: Int) -> CheckResult {
        let result = OCCTCheckVertex(handle, Int32(index))
        let status = CheckStatus(rawValue: Int32(result.firstError.rawValue))
        return CheckResult(
            isValid: result.isValid,
            errorCount: Int(result.errorCount),
            firstError: result.errorCount > 0 ? status : nil
        )
    }

    // MARK: - BRepExtrema_ExtCC (Edge-Edge Extrema)

    /// Result of edge-edge distance extrema computation
    public struct EdgeEdgeExtrema: Sendable {
        /// Minimum distance between the edges
        public let distance: Double
        /// Parameter on the first edge at closest point
        public let paramOnEdge1: Double
        /// Parameter on the second edge at closest point
        public let paramOnEdge2: Double
        /// Closest point on edge 1
        public let pointOnEdge1: SIMD3<Double>
        /// Closest point on edge 2
        public let pointOnEdge2: SIMD3<Double>
        /// Whether the edges are parallel
        public let isParallel: Bool
        /// Number of extrema solutions
        public let solutionCount: Int
    }

    // MARK: - v0.51.0: BRepLib_MakeSolid, GC transforms, ChFi2d_AnaFilletAlgo

    /// Create a solid from a shell shape using BRepLib_MakeSolid.
    ///
    /// - Parameter shell: A shape containing a shell (e.g., from shellFromSurface)
    /// - Returns: Solid shape, or nil on failure
    public static func solidFromShell(_ shell: Shape) -> Shape? {
        guard let h = OCCTShapeMakeSolidFromShell(shell.handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - BRepTools_Substitution

    /// Substitute a sub-shape within this shape.
    ///
    /// Replaces one topological sub-shape (vertex, edge, face) with another
    /// and rebuilds the parent shape.
    ///
    /// - Parameters:
    ///   - oldSubShape: The sub-shape to replace
    ///   - newSubShape: The replacement sub-shape
    /// - Returns: Modified shape, or nil on failure
    public func substituted(replacing oldSubShape: Shape, with newSubShape: Shape) -> Shape? {
        guard let h = OCCTBRepToolsSubstitute(handle, oldSubShape.handle, newSubShape.handle) else {
            return nil
        }
        return Shape(handle: h)
    }

    // MARK: BRepLib_MakeEdge

    /// Create an edge from a line with parameter bounds.
    public static func edgeFromLine(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeEdgeFromLine(
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            p1, p2
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create an edge from two 3D points (BRepLib).
    public static func edgeFromPoints(
        _ p1: SIMD3<Double>,
        _ p2: SIMD3<Double>
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeEdgeFromPoints(
            p1.x, p1.y, p1.z, p2.x, p2.y, p2.z
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create an edge from a circle arc with parameter bounds.
    public static func edgeFromCircle(
        center: SIMD3<Double>,
        axis: SIMD3<Double>,
        radius: Double,
        p1: Double,
        p2: Double
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeEdgeFromCircle(
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z,
            radius, p1, p2
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepLib_MakeFace

    /// Create a face from a plane surface with UV bounds.
    public static func faceFromPlane(
        origin: SIMD3<Double>,
        normal: SIMD3<Double>,
        uRange: ClosedRange<Double>,
        vRange: ClosedRange<Double>,
        tolerance: Double = 1e-6
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeFaceFromPlane(
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z,
            uRange.lowerBound, uRange.upperBound,
            vRange.lowerBound, vRange.upperBound,
            tolerance
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Create a face from a cylindrical surface with UV bounds.
    public static func faceFromCylinder(
        origin: SIMD3<Double>,
        axis: SIMD3<Double>,
        radius: Double,
        uRange: ClosedRange<Double>,
        vRange: ClosedRange<Double>,
        tolerance: Double = 1e-6
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeFaceFromCylinder(
            origin.x, origin.y, origin.z,
            axis.x, axis.y, axis.z,
            radius,
            uRange.lowerBound, uRange.upperBound,
            vRange.lowerBound, vRange.upperBound,
            tolerance
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepLib_MakeShell

    /// Create a shell from a plane surface with UV bounds.
    public static func shellFromPlane(
        origin: SIMD3<Double>,
        normal: SIMD3<Double>,
        uRange: ClosedRange<Double>,
        vRange: ClosedRange<Double>
    ) -> Shape? {
        guard let h = OCCTBRepLibMakeShellFromPlane(
            origin.x, origin.y, origin.z,
            normal.x, normal.y, normal.z,
            uRange.lowerBound, uRange.upperBound,
            vRange.lowerBound, vRange.upperBound
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: BRepLib_ToolTriangulatedShape

    /// Compute normals on the triangulation of all faces in this shape.
    /// The shape must be meshed first.
    public func computeNormals() -> Bool {
        OCCTBRepLibComputeNormals(handle)
    }

    // MARK: BRepLib_PointCloudShape

    /// Point cloud result with positions and normals.
    public struct PointCloudResult: Sendable {
        public let points: [SIMD3<Double>]
        public let normals: [SIMD3<Double>]
    }

    /// Unpacks the bridge's raw `points`/`normals` double arrays (3 doubles per sample, `count`
    /// samples) into a `PointCloudResult`, freeing both buffers. Shared by
    /// ``pointCloudByTriangulation()``/``pointCloudByDensity(_:)`` (#796) — the two differ only in
    /// which bridge call produces the raw arrays, not in how the result is unpacked.
    private static func unpackPointCloud(points: UnsafeMutablePointer<Double>,
                                          normals: UnsafeMutablePointer<Double>,
                                          count: Int32) -> PointCloudResult {
        defer { free(points); free(normals) }
        var pts = [SIMD3<Double>]()
        var nms = [SIMD3<Double>]()
        pts.reserveCapacity(Int(count))
        nms.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            pts.append(SIMD3(points[i*3], points[i*3+1], points[i*3+2]))
            nms.append(SIMD3(normals[i*3], normals[i*3+1], normals[i*3+2]))
        }
        return PointCloudResult(points: pts, normals: nms)
    }

    /// Generate a point cloud from this shape's triangulation.
    /// The shape must be meshed first.
    public func pointCloudByTriangulation() -> PointCloudResult? {
        var outPoints: UnsafeMutablePointer<Double>?
        var outNormals: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTBRepLibPointCloudByTriangulation(handle, &outPoints, &outNormals, &outCount),
              let pts = outPoints, let nms = outNormals, outCount > 0 else { return nil }
        return Shape.unpackPointCloud(points: pts, normals: nms, count: outCount)
    }

    /// Generate a point cloud from this shape by density (points per unit area).
    /// The shape must be meshed first.
    public func pointCloudByDensity(_ density: Double) -> PointCloudResult? {
        var outPoints: UnsafeMutablePointer<Double>?
        var outNormals: UnsafeMutablePointer<Double>?
        var outCount: Int32 = 0
        guard OCCTBRepLibPointCloudByDensity(handle, density, &outPoints, &outNormals, &outCount),
              let pts = outPoints, let nms = outNormals, outCount > 0 else { return nil }
        return Shape.unpackPointCloud(points: pts, normals: nms, count: outCount)
    }

    /// Check if this shape is empty (has no sub-shapes).
    ///
    /// Uses BOPTools_AlgoTools3D::IsEmptyShape.
    public var isEmpty: Bool {
        OCCTBOPToolsIsEmptyShape(handle)
    }

    // MARK: - v0.73.0: TKHlr — Extended HLR, ReflectLines, TopCnx, Intrv

    /// Fine-grained HLR edge categories for exact and polygon-based hidden line removal.
    public enum HLREdgeCategory: Int32, Sendable {
        case visibleSharp = 0       /// Visible C0-continuity (sharp) edges
        case visibleSmooth = 1      /// Visible G1-continuity (smooth) edges
        case visibleSewn = 2        /// Visible CN-continuity (sewn) edges
        case visibleOutline = 3     /// Visible silhouette/outline edges
        case visibleIso = 4         /// Visible isoparameter lines (exact HLR only)
        case visibleOutline3d = 5   /// Visible outline edges in 3D (exact HLR only)
        case hiddenSharp = 6        /// Hidden C0-continuity (sharp) edges
        case hiddenSmooth = 7       /// Hidden G1-continuity (smooth) edges
        case hiddenSewn = 8         /// Hidden CN-continuity (sewn) edges
        case hiddenOutline = 9      /// Hidden silhouette/outline edges
        case hiddenIso = 10         /// Hidden isoparameter lines (exact HLR only)
    }

    /// HLR resulting edge type for generic CompoundOfEdges and ReflectLines APIs.
    public enum HLREdgeType: Int32, Sendable {
        case undefined = 0
        case isoLine = 1
        case outLine = 2
        case rg1Line = 3   /// G1-continuity smooth
        case rgNLine = 4   /// CN-continuity sewn
        case sharp = 5     /// C0-continuity sharp
    }

    /// Get edges by fine-grained category using exact HLR (hidden line removal).
    public func hlrEdges(direction: SIMD3<Double>, category: HLREdgeCategory) -> Shape? {
        guard let h = OCCTHLRGetEdgesByCategory(handle, direction.x, direction.y, direction.z,
            OCCTHLREdgeCategory(rawValue: UInt32(category.rawValue))) else { return nil }
        return Shape(handle: h)
    }

    /// Get edges by fine-grained category using fast polygon-based HLR.
    ///
    /// Polyhedral HLR projects the shape's *triangulation*, so it is dramatically faster than
    /// exact `hlrEdges` on curved surfaces — e.g. ~48× on an analytic helicoid thread (#196).
    /// Prefer this for 2D drawings of threaded / curved solids.
    ///
    /// - Parameters:
    ///   - direction: View direction.
    ///   - category: Edge category to extract.
    ///   - deflection: Linear mesh deflection (mm) for the internal triangulation. Smaller = finer
    ///     drawing (more, shorter edges); larger = coarser and faster. Default `0.1`. Meshing is
    ///     *incremental* (`BRepMesh_IncrementalMesh`): it refines but never coarsens an existing
    ///     triangulation, so on a shape already meshed more finely (e.g. by a prior export) this
    ///     value is a floor, not an override.
    /// - Note: `.visibleIso`, `.hiddenIso`, and `.visibleOutline3d` are not available for poly HLR.
    public func hlrPolyEdges(direction: SIMD3<Double>, category: HLREdgeCategory,
                             deflection: Double = 0.1) -> Shape? {
        guard let h = OCCTHLRPolyGetEdgesByCategory(handle, direction.x, direction.y, direction.z,
            OCCTHLREdgeCategory(rawValue: UInt32(category.rawValue)), deflection) else { return nil }
        return Shape(handle: h)
    }

    /// Get edges using the generic CompoundOfEdges API from exact HLR.
    public func hlrCompoundOfEdges(direction: SIMD3<Double>, edgeType: HLREdgeType,
                                    visible: Bool, in3d: Bool) -> Shape? {
        guard let h = OCCTHLRCompoundOfEdges(handle, direction.x, direction.y, direction.z,
            edgeType.rawValue, visible, in3d) else { return nil }
        return Shape(handle: h)
    }

    /// Result of edge-face transition computation.
    public struct EdgeFaceTransitionResult: Sendable {
        /// TopAbs_Orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
        public let transition: Int
        /// TopAbs_Orientation for boundary
        public let boundaryTransition: Int
    }

    /// Face interference description for edge-face transition computation.
    public struct FaceInterference: Sendable {
        public let tangent: SIMD3<Double>
        public let normal: SIMD3<Double>
        public let curvature: Double
        public let orientation: Int32      // TopAbs_Orientation
        public let transition: Int32       // TopAbs_Orientation
        public let boundaryTransition: Int32 // TopAbs_Orientation
        public let tolerance: Double

        public init(tangent: SIMD3<Double>, normal: SIMD3<Double>, curvature: Double,
                    orientation: Int32, transition: Int32, boundaryTransition: Int32,
                    tolerance: Double) {
            self.tangent = tangent
            self.normal = normal
            self.curvature = curvature
            self.orientation = orientation
            self.transition = transition
            self.boundaryTransition = boundaryTransition
            self.tolerance = tolerance
        }
    }

    /// Compute cumulated edge-face transition for multiple face interferences on an edge.
    /// - Parameters:
    ///   - edgeTangent: Edge tangent direction
    ///   - edgeNormal: Edge normal direction (zero vector for linear edges)
    ///   - edgeCurvature: Edge curvature (0 for linear edges)
    ///   - faces: Array of face interference descriptions
    /// - Returns: Transition result with cumulated orientation
    public static func edgeFaceTransition(edgeTangent: SIMD3<Double>,
                                          edgeNormal: SIMD3<Double>,
                                          edgeCurvature: Double,
                                          faces: [FaceInterference]) -> EdgeFaceTransitionResult {
        var faceTangents: [Double] = []
        var faceNormals: [Double] = []
        var faceCurvatures: [Double] = []
        var faceOrientations: [Int32] = []
        var faceTransitions: [Int32] = []
        var faceBoundaryTr: [Int32] = []
        var tolerances: [Double] = []

        for face in faces {
            faceTangents.append(contentsOf: [face.tangent.x, face.tangent.y, face.tangent.z])
            faceNormals.append(contentsOf: [face.normal.x, face.normal.y, face.normal.z])
            faceCurvatures.append(face.curvature)
            faceOrientations.append(face.orientation)
            faceTransitions.append(face.transition)
            faceBoundaryTr.append(face.boundaryTransition)
            tolerances.append(face.tolerance)
        }

        let r = OCCTTopCnxEdgeFaceTransition(
            edgeTangent.x, edgeTangent.y, edgeTangent.z,
            edgeNormal.x, edgeNormal.y, edgeNormal.z,
            edgeCurvature,
            faceTangents, faceNormals, faceCurvatures,
            faceOrientations, faceTransitions, faceBoundaryTr,
            tolerances, Int32(faces.count))

        return EdgeFaceTransitionResult(
            transition: Int(r.transition),
            boundaryTransition: Int(r.boundaryTransition))
    }

    /// Deep copy a shape via BRepTools_CopyModification.
    ///
    /// Same underlying mechanism as ``copy(copyGeometry:copyMesh:)`` (`BRepBuilderAPI_Copy` is a
    /// thin wrapper around this same class), reached directly instead — note the different
    /// `copyMesh` default (`true` here vs. `false` on `copy()`). Clones geometry/mesh when the
    /// respective flag is `true`, unlike the no-argument instance ``deepCopy()``, which never does.
    public static func deepCopy(_ shape: Shape, copyGeometry: Bool = true, copyMesh: Bool = true) -> Shape? {
        guard let ref = OCCTShapeCopyModification(shape.handle, copyGeometry, copyMesh) else { return nil }
        return Shape(handle: ref)
    }

    /// Evaluate the edge curve at a parameter.
    public func edgeAdaptorValue(at param: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeAdaptorValue(handle, param, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Curve type of the edge (GeomAbs_CurveType: 0=Line, 1=Circle, etc.).
    public var edgeAdaptorCurveType: Int32 {
        OCCTEdgeAdaptorCurveType(handle)
    }

    /// Get the UV bounds of a face surface.
    public var faceAdaptorBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin = 0.0, uMax = 0.0, vMin = 0.0, vMax = 0.0
        OCCTFaceAdaptorBounds(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Evaluate the face surface at (u,v).
    public func faceAdaptorValue(u: Double, v: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTFaceAdaptorValue(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Surface type of the face (GeomAbs_SurfaceType: 0=Plane, 1=Cylinder, etc.).
    public var faceAdaptorSurfaceType: Int32 {
        OCCTFaceAdaptorSurfaceType(handle)
    }

    // --- Additional shape queries ---

    /// Volume of the oriented bounding box (OBB).
    public var obbVolume: Double {
        OCCTShapeOBBVolume(handle)
    }

    /// Maximum edge tolerance in this shape.
    public var maxEdgeTolerance: Double {
        OCCTShapeMaxEdgeTolerance(handle)
    }

    /// Maximum face tolerance in this shape.
    public var maxFaceTolerance: Double {
        OCCTShapeMaxFaceTolerance(handle)
    }

    /// Maximum vertex tolerance in this shape.
    public var maxVertexTolerance: Double {
        OCCTShapeMaxVertexTolerance(handle)
    }

    /// Whether this shape has free (non-shared) edges.
    public var hasFreeEdges: Bool {
        OCCTShapeHasFreeEdges(handle)
    }

    /// Whether this shape has free (non-shared) wires.
    public var hasFreeWires: Bool {
        OCCTShapeHasFreeWires(handle)
    }

    /// Whether this shape has free (non-shared) faces.
    public var hasFreeFaces: Bool {
        OCCTShapeHasFreeFaces(handle)
    }

    /// Length of the bounding box diagonal.
    public var boundingDiagonal: Double {
        OCCTShapeBoundingDiagonal(handle)
    }
    /// Get the 2D curve (pcurve) of an edge on a face, with parameter range.
    public static func curveOnSurface(edge: Shape, face: Shape) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let c = OCCTBRepToolCurveOnSurface(edge.handle, face.handle, &first, &last) else { return nil }
        return (Curve2D(handle: c), first, last)
    }

    /// Check if edge has continuity regularity between two faces.
    public static func hasContinuity(edge: Shape, face1: Shape, face2: Shape) -> Bool {
        OCCTBRepToolHasContinuity(edge.handle, face1.handle, face2.handle)
    }

    /// Get the continuity of edge between two faces. Returns GeomAbs_Shape as int.
    public static func continuity(edge: Shape, face1: Shape, face2: Shape) -> Int {
        Int(OCCTBRepToolContinuity(edge.handle, face1.handle, face2.handle))
    }

    /// Check if edge has any regularity on some two surfaces.
    public static func hasAnyContinuity(edge: Shape) -> Bool {
        OCCTBRepToolHasAnyContinuity(edge.handle)
    }

    /// Get the maximum continuity of edge between all its surfaces.
    public static func maxContinuity(edge: Shape) -> Int {
        Int(OCCTBRepToolMaxContinuity(edge.handle))
    }

    /// Check if edge is degenerated.
    public static func isDegenerated(edge: Shape) -> Bool {
        OCCTBRepToolDegenerated(edge.handle)
    }

    /// Check if face has the NaturalRestriction flag set.
    public static func naturalRestriction(face: Shape) -> Bool {
        OCCTBRepToolNaturalRestriction(face.handle)
    }

    /// Get the parameter range of edge on a face (pcurve range).
    public static func rangeOnFace(edge: Shape, face: Shape) -> (first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard OCCTBRepToolRangeOnFace(edge.handle, face.handle, &first, &last) else { return nil }
        return (first, last)
    }

    /// Get the parameter of vertex on pcurve of edge on face.
    public static func parameterOnFace(vertex: Shape, edge: Shape, face: Shape) -> Double? {
        var param = 0.0
        guard OCCTBRepToolParameterOnFace(vertex.handle, edge.handle, face.handle, &param) else { return nil }
        return param
    }

    /// Get the UV parameters of vertex on face.
    public static func parametersOnFace(vertex: Shape, face: Shape) -> (u: Double, v: Double)? {
        var u = 0.0, v = 0.0
        guard OCCTBRepToolParametersOnFace(vertex.handle, face.handle, &u, &v) else { return nil }
        return (u, v)
    }

    /// Get UV points at extremities of edge on face.
    public static func uvPoints(edge: Shape, face: Shape) -> (firstU: Double, firstV: Double, lastU: Double, lastV: Double)? {
        var fU = 0.0, fV = 0.0, lU = 0.0, lV = 0.0
        guard OCCTBRepToolUVPoints(edge.handle, face.handle, &fU, &fV, &lU, &lV) else { return nil }
        return (fU, fV, lU, lV)
    }

    /// Get maximum tolerance of sub-shapes of given type. type: 6=EDGE, 4=FACE, 7=VERTEX.
    ///
    /// This is the real `TopAbs_ShapeEnum` ordinal, the same convention ``ShapeType``'s raw
    /// values use and the same one the `ShapeType`-typed `maxTolerance(type:)` overload passes
    /// through unchanged — but NOT the same as the compressed `Int` `maxTolerance(type: Int)`
    /// overload uses (#833): the two `Int`-based overloads disagree on what `2` means.
    public func maxTolerance(subShapeType: Int) -> Double {
        OCCTBRepToolMaxTolerance(handle, Int32(subShapeType))
    }

    /// Get the 2D curve of an edge computed on a plane surface.
    /// Uses BRep_Tool::CurveOnPlane.
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - surface: The surface (typically planar)
    /// - Returns: The 2D curve and parameter range, or nil
    public static func curveOnPlane(edge: Shape, surface: Surface) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTBRepToolCurveOnPlane(edge.handle, surface.handle, &first, &last) else { return nil }
        return (Curve2D(handle: ref), first, last)
    }

    /// Get the 3D polygon of a meshed edge (from BRep_Tool::Polygon3D).
    /// The shape should be meshed first (e.g., via `mesh(deflection:)`).
    /// - Parameter edge: The edge shape
    /// - Returns: Array of 3D points, or nil if no polygon available
    public static func polygon3D(edge: Shape) -> [SIMD3<Double>]? {
        var pointsPtr: UnsafeMutablePointer<Double>?
        let count = OCCTBRepToolPolygon3D(edge.handle, &pointsPtr)
        guard count > 0, let pts = pointsPtr else { return nil }
        defer { free(pts) }
        var result = [SIMD3<Double>]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(SIMD3(pts[i*3], pts[i*3+1], pts[i*3+2]))
        }
        return result
    }

    /// Get the polygon-on-triangulation indices of a meshed edge.
    /// Returns 1-based node indices into the triangulation.
    /// The shape should be meshed first.
    /// - Parameter edge: The edge shape
    /// - Returns: Array of 1-based node indices, or nil if not available
    public static func polygonOnTriangulation(edge: Shape) -> [Int]? {
        var indicesPtr: UnsafeMutablePointer<Int32>?
        let count = OCCTBRepToolPolygonOnTriangulation(edge.handle, &indicesPtr)
        guard count > 0, let indices = indicesPtr else { return nil }
        defer { free(indices) }
        var result = [Int]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(Int(indices[i]))
        }
        return result
    }

    /// Check if an edge is closed on a face (has two PCurves with different orientations).
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - face: The face shape
    /// - Returns: true if the edge is closed on the face
    public static func isClosedOnFace(edge: Shape, face: Shape) -> Bool {
        OCCTBRepToolIsClosedOnFace(edge.handle, face.handle)
    }

    /// Get the 2D polygon of an edge on a face (from BRep_Tool::PolygonOnSurface).
    /// The shape should be meshed first.
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - face: The face shape
    /// - Returns: Array of 2D UV points, or nil if not available
    public static func polygonOnSurface(edge: Shape, face: Shape) -> [SIMD2<Double>]? {
        var pointsPtr: UnsafeMutablePointer<Double>?
        let count = OCCTBRepToolPolygonOnSurface(edge.handle, face.handle, &pointsPtr)
        guard count > 0, let pts = pointsPtr else { return nil }
        defer { free(pts) }
        var result = [SIMD2<Double>]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            result.append(SIMD2(pts[i*2], pts[i*2+1]))
        }
        return result
    }

    /// Set the UV endpoint coordinates of an edge on a face.
    /// - Parameters:
    ///   - edge: The edge shape
    ///   - face: The face shape
    ///   - first: UV coordinates of the first point
    ///   - last: UV coordinates of the last point
    /// - Returns: true on success
    @discardableResult
    public static func setUVPoints(edge: Shape, face: Shape,
                                    first: SIMD2<Double>, last: SIMD2<Double>) -> Bool {
        OCCTBRepToolSetUVPoints(edge.handle, face.handle, first.x, first.y, last.x, last.y)
    }
}

extension Shape {

    /// Create a deep copy of this shape (independent copy with new topology).
    ///
    /// - Note: **Topology only** (#831). Backed by `TNaming_CopyShape::CopyTool`, which builds new
    ///   `TopoDS_TShape`s but assigns the *same* `Handle(Geom_Surface)`/`Handle(Geom_Curve)`/
    ///   `Handle(Poly_Triangulation)` to the copy — no geometry or mesh cloning. For a copy whose
    ///   geometry is also independent (e.g. for concurrent use on separate threads — see
    ///   `docs/thread-safety.md`), use ``copy(copyGeometry:copyMesh:)`` or the static
    ///   ``deepCopy(_:copyGeometry:copyMesh:)`` instead, both backed by `BRepTools_CopyModification`
    ///   / `BRepBuilderAPI_Copy`, which do clone the geometry when `copyGeometry` is `true`.
    public func deepCopy() -> Shape? {
        guard let ref = OCCTShapeDeepCopy(handle) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Write shape to binary data.
    public func toBinaryData() -> Data? {
        var length: Int32 = 0
        guard let ptr = OCCTBinToolsWriteShape(handle, &length) else { return nil }
        let data = Data(bytes: ptr, count: Int(length))
        free(UnsafeMutableRawPointer(mutating: ptr))
        return data
    }

    /// Read shape from binary data.
    public static func fromBinaryData(_ data: Data) -> Shape? {
        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return nil }
            guard let ref = OCCTBinToolsReadShape(ptr, Int32(data.count)) else { return nil }
            return Shape(handle: ref)
        }
    }

    /// Write shape to binary file.
    @discardableResult
    public func writeBinary(to url: URL) -> Bool {
        OCCTBinToolsWriteShapeToFile(handle, url.path)
    }

    /// Read shape from binary file.
    public static func loadBinary(from url: URL) -> Shape? {
        guard let ref = OCCTBinToolsReadShapeFromFile(url.path) else { return nil }
        return Shape(handle: ref)
    }
}

public extension Shape {
    /// Result of contiguous edge finding.
    struct ContigousEdgeResult: Sendable {
        public let contigousEdgeCount: Int
        public let degeneratedShapeCount: Int
    }

    /// Find contiguous edges in a shape.
    func findContigousEdges(tolerance: Double = 1.0e-6) -> ContigousEdgeResult {
        let result = OCCTShapeFindContigousEdges(handle, tolerance)
        return ContigousEdgeResult(
            contigousEdgeCount: Int(result.contigousEdgeCount),
            degeneratedShapeCount: Int(result.degeneratedShapeCount)
        )
    }
}

extension Shape {

    /// Create a deep copy of this shape using TNaming_Translator.
    /// The copy has independent topology (different TShape pointers).
    public func translatorCopy() -> Shape? {
        guard let ref = OCCTShapeTranslatorCopy(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Check if two shapes share the same underlying TShape.
    public func isSame(as other: Shape) -> Bool {
        OCCTShapeIsSame(handle, other.handle)
    }
}

extension Shape {

    /// Classification state for a point relative to a solid.
    ///
    /// - Note: ``classify(point:tolerance:)`` (`Shape+Analysis.swift`) answers the identical
    ///   question — same `BRepClass3d_SolidClassifier` mechanism (#851), same tolerance
    ///   semantics, same underlying `TopAbs_State` values — but returns the separately-declared
    ///   ``PointClassification`` instead. The two enums share raw values case-for-case (`inside=0,
    ///   outside=1, on/onBoundary=2, unknown=3`) but **not** case names (`.on` here vs.
    ///   `.onBoundary` there), so they are intentionally kept as two declarations rather than a
    ///   typealias — unlike ``Face/SurfaceType`` (#850), whose case names matched exactly, a
    ///   typealias here would silently rename one side's cases and break source compatibility for
    ///   whichever spelling was renamed away. Do not conflate the two by raw value across API
    ///   boundaries you don't control.
    public enum PointState: Int32 {
        case inside = 0
        case outside = 1
        case on = 2
        case unknown = 3
    }

    /// Classify a 3D point relative to this solid shape.
    ///
    /// Equivalent to ``classify(point:tolerance:)`` — both route through
    /// `BRepClass3d_SolidClassifier` (#851) — but returns ``PointState`` instead of
    /// ``PointClassification``. Prefer whichever result enum your call site already uses; the two
    /// never disagree since they share one bridge mechanism and a common `TopAbs_State` mapping.
    ///
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Classification tolerance
    /// - Returns: The classification state
    public func classifyPoint(_ point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointState {
        let raw = OCCTShapeClassifyPoint(handle, point.x, point.y, point.z, tolerance)
        return PointState(rawValue: raw) ?? .unknown
    }
}

extension Shape {

    /// Classify a 2D point on a face (in UV parameter space).
    /// - Parameters:
    ///   - faceIndex: Face index (0-based)
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - tolerance: Classification tolerance
    /// - Returns: Classification state
    public func classifyPoint2D(faceIndex: Int, u: Double, v: Double, tolerance: Double = 1e-6) -> PointState {
        let raw = OCCTShapeClassifyPoint2D(handle, Int32(faceIndex), u, v, tolerance)
        return PointState(rawValue: raw) ?? .unknown
    }
}

extension Shape {

    /// Get the first (FORWARD) vertex position of an edge shape.
    public func edgeFirstVertex() -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeFirstVertex(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get the last (REVERSED) vertex position of an edge shape.
    public func edgeLastVertex() -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeLastVertex(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get both vertex positions of an edge shape.
    public func edgeVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)? {
        var x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0
        guard OCCTEdgeVertices(handle, &x1, &y1, &z1, &x2, &y2, &z2) else { return nil }
        return (SIMD3(x1, y1, z1), SIMD3(x2, y2, z2))
    }

    /// Get first and last vertex positions of a wire shape. For closed wires, both are the same.
    public func wireVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)? {
        var x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0
        guard OCCTWireVertices(handle, &x1, &y1, &z1, &x2, &y2, &z2) else { return nil }
        return (SIMD3(x1, y1, z1), SIMD3(x2, y2, z2))
    }

    /// Find common vertex between two edge shapes. Returns nil if no shared vertex.
    public func commonVertex(with other: Shape) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeCommonVertex(handle, other.handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Build edge→face adjacency. Returns array where each element is the number of faces sharing that edge.
    public func edgeFaceAdjacency() -> [Int] {
        let count = Int(OCCTEdgeFaceAdjacency(handle, nil))
        guard count > 0 else { return [] }
        var counts = [Int32](repeating: 0, count: count)
        _ = OCCTEdgeFaceAdjacency(handle, &counts)
        return counts.map { Int($0) }
    }

    /// Build vertex→edge adjacency. Returns array where each element is the number of edges sharing that vertex.
    public func vertexEdgeAdjacency() -> [Int] {
        let count = Int(OCCTVertexEdgeAdjacency(handle, nil))
        guard count > 0 else { return [] }
        var counts = [Int32](repeating: 0, count: count)
        _ = OCCTVertexEdgeAdjacency(handle, &counts)
        return counts.map { Int($0) }
    }

    /// The 0-based indices of the faces adjacent to `edge` within this shape.
    ///
    /// The indices address the same enumeration ``Shape/face(at:)`` reads, so they can be handed
    /// straight to it. They used to be 1-based, which named the face before the intended one and
    /// could never name face 0 (#541).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.subShapes(ofType: .edge).first!
    /// for i in box.adjacentFaces(forEdge: edge) {
    ///     print(box.face(at: i)!.area())   // the two faces meeting at that edge
    /// }
    /// ```
    public func adjacentFaces(forEdge edge: Shape) -> [Int] {
        var indices = [Int32](repeating: 0, count: 64)
        let count = Int(OCCTEdgeAdjacentFaces(handle, edge.handle, &indices, 64))
        return indices.prefix(count).map { Int($0) }
    }

    /// The 0-based indices of the edges meeting `vertex` within this shape.
    ///
    /// The indices address the same enumeration ``Shape/subShape(type:index:)`` reads for
    /// `.edge`. They used to be 1-based (#541).
    public func adjacentEdges(forVertex vertex: Shape) -> [Int] {
        var indices = [Int32](repeating: 0, count: 64)
        let count = Int(OCCTVertexAdjacentEdges(handle, vertex.handle, &indices, 64))
        return indices.prefix(count).map { Int($0) }
    }
}

extension Shape {

    /// Edge orientation from wire explorer.
    public enum EdgeOrientation: Int, Sendable {
        case forward = 0
        case reversed = 1
        case `internal` = 2
        case external = 3
    }

    /// Get edge orientations within a wire, optionally with face context.
    public func wireEdgeOrientations(face: Shape? = nil) -> [EdgeOrientation] {
        let count = Int(OCCTWireExplorerOrientations(handle, face?.handle, nil))
        guard count > 0 else { return [] }
        var orientations = [Int32](repeating: 0, count: count)
        _ = OCCTWireExplorerOrientations(handle, face?.handle, &orientations)
        return orientations.map { EdgeOrientation(rawValue: Int($0)) ?? .forward }
    }

    /// Get connecting vertex positions from wire explorer (vertex between consecutive edges).
    public func wireExplorerVertices(face: Shape? = nil) -> [SIMD3<Double>] {
        let count = Int(OCCTWireExplorerVertices(handle, face?.handle, nil, nil, nil))
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        _ = OCCTWireExplorerVertices(handle, face?.handle, &xs, &ys, &zs)
        return (0..<count).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }
}

extension Shape {
    /// Substitute a subshape with a list of new shapes. Pass empty array to remove.
    public func substitute(oldSubShape: Shape, newSubShapes: [Shape]) -> Shape? {
        if newSubShapes.isEmpty {
            return withUnsafePointer(to: Optional<OCCTShapeRef>.none) { _ in
                guard let h = OCCTShapeSubstitute(handle, oldSubShape.handle, nil, 0) else { return nil }
                return Shape(handle: h)
            }
        }
        var handles = newSubShapes.map { $0.handle as OCCTShapeRef? }
        return handles.withUnsafeMutableBufferPointer { buf in
            guard let h = OCCTShapeSubstitute(handle, oldSubShape.handle, buf.baseAddress, Int32(newSubShapes.count)) else {
                return nil
            }
            return Shape(handle: h)
        }
    }

    /// Check if a subshape was copied during substitution.
    public func substitutionIsCopied(subshape: Shape) -> Bool {
        OCCTSubstitutionIsCopied(handle, subshape.handle)
    }
}

extension Shape {
    /// Create a vertex shape at the given point using BRepLib_MakeVertex.
    public static func makeVertex(at point: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTMakeVertex(point.x, point.y, point.z) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Shape orientation values.
    public enum Orientation: Int32, Sendable {
        case forward = 0
        case reversed = 1
        case `internal` = 2
        case external = 3
    }

    /// Get shape orientation.
    public var orientation: Orientation {
        Orientation(rawValue: OCCTShapeGetOrientation(handle)) ?? .forward
    }

    /// Set shape orientation.
    public func setOrientation(_ orient: Orientation) {
        OCCTShapeSetOrientation(handle, orient.rawValue)
    }

    /// Get a reversed copy of the shape.
    public var reversed: Shape? {
        guard let h = OCCTShapeReversed(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get a complemented copy of the shape (reversed orientation).
    public var complemented: Shape? {
        guard let h = OCCTShapeComplemented(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Compose with another orientation.
    public func composed(with orient: Orientation) -> Shape? {
        guard let h = OCCTShapeComposed(handle, orient.rawValue) else { return nil }
        return Shape(handle: h)
    }

    /// Check if the shape's Free flag is set.
    public var isFree: Bool {
        OCCTShapeIsFree(handle)
    }

    /// Check if the shape's Modified flag is set.
    public var isModified: Bool {
        OCCTShapeIsModified(handle)
    }

    /// Check if the shape's Checked flag is set.
    public var isChecked: Bool {
        OCCTShapeIsChecked(handle)
    }

    /// Check if the shape's Orientable flag is set.
    public var isOrientable: Bool {
        OCCTShapeIsOrientable(handle)
    }

    /// Check if the shape's Infinite flag is set.
    public var isInfinite: Bool {
        OCCTShapeIsInfinite(handle)
    }

    /// Check if the shape's Convex flag is set.
    public var isConvex: Bool {
        OCCTShapeIsConvex(handle)
    }

    /// Check if the shape is empty (null underlying shape).
    public var isEmptyShape: Bool {
        OCCTShapeIsEmpty(handle)
    }

    /// Check if two shapes are partners (same TShape).
    public func isPartner(with other: Shape) -> Bool {
        OCCTShapeIsPartner(handle, other.handle)
    }

    /// Check if two shapes are equal (same TShape + same location + same orientation).
    public func isEqual(to other: Shape) -> Bool {
        OCCTShapeIsEqual(handle, other.handle)
    }

    /// Get the number of direct children sub-shapes.
    public var nbChildren: Int {
        Int(OCCTShapeNbChildren(handle))
    }

    /// Get the hash code of a shape.
    public var hashCode: Int {
        Int(OCCTShapeHashCode(handle))
    }
}

extension Shape {

    /// Clean all tessellation data from the shape.
    public func clean() {
        OCCTShapeClean(handle)
    }

    /// Clean geometry (PCurves etc.) from the shape.
    public func cleanGeometry() {
        OCCTShapeCleanGeometry(handle)
    }

    /// Remove unused PCurves from edges.
    public func removeUnusedPCurves() {
        OCCTShapeRemoveUnusedPCurves(handle)
    }

    /// Update BRep data structures.
    public func updateShape() {
        OCCTShapeUpdate(handle)
    }

    /// Check if an edge has same-range parametrisation.
    public static func checkSameRange(edge: Shape) -> Bool {
        OCCTBRepLibCheckSameRange(edge.handle)
    }

    /// Ensure edge has same-range parametrisation.
    @discardableResult
    public static func sameRange(edge: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTBRepLibSameRange(edge.handle, tolerance)
    }

    /// Build 3D curve for an edge from PCurves.
    @discardableResult
    public static func buildCurve3d(edge: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTBRepLibBuildCurve3d(edge.handle, tolerance)
    }

    /// Update tolerances of all sub-shapes.
    public func updateTolerances() {
        OCCTBRepLibUpdateTolerances(handle)
    }

    /// Update inner tolerances of all sub-shapes.
    public func updateInnerTolerances() {
        OCCTBRepLibUpdateInnerTolerances(handle)
    }

    /// Update tolerance of a specific edge.
    @discardableResult
    public static func updateEdgeTolerance(edge: Shape, tolerance: Double) -> Bool {
        OCCTBRepLibUpdateEdgeTolerance(edge.handle, tolerance)
    }
}

extension Shape {

    /// Create a face from a sphere with UV bounds.
    public static func faceFromSphere(center: SIMD3<Double> = .zero, radius: Double,
                                       uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromSphere(center.x, center.y, center.z, radius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a torus with UV bounds.
    public static func faceFromTorus(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                      majorRadius: Double, minorRadius: Double,
                                      uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromTorus(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                               majorRadius, minorRadius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a cone with UV bounds.
    public static func faceFromCone(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                     semiAngle: Double, radius: Double,
                                     uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromCone(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                              semiAngle, radius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a surface trimmed by a wire.
    public static func faceFromSurface(_ surface: Surface, wire: Shape, inside: Bool = true) -> Shape? {
        guard let ref = OCCTMakeFaceFromSurfaceWire(surface.handle, wire.handle, inside) else { return nil }
        return Shape(handle: ref)
    }

    /// Add a hole (inner wire) to a face.
    ///
    /// The hole wire may be **polygonal or curved** (a `Wire.circle`, an arc, joined arcs) and may
    /// wind either way: the wire is reoriented as needed so the hole always *removes* area, and the
    /// holed face extrudes into a valid solid with a real through hole.
    ///
    /// ```swift
    /// let plate = Shape.face(from: Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(20, 0, 0),
    ///                                              SIMD3(20, 20, 0), SIMD3(0, 20, 0)],
    ///                                             closed: true)!, planar: true)!
    /// let bore = Shape.fromWire(Wire.circle(origin: SIMD3(10, 10, 0),
    ///                                       normal: SIMD3(0, 0, 1), radius: 3)!)!
    /// let holed = Shape.faceAddHole(face: plate, wire: bore)!
    /// holed.surfaceArea          // 400 - pi*9
    /// holed.extruded(by: SIMD3(0, 0, 5))!.isValidSolid   // true, hole runs through
    /// ```
    ///
    /// - Returns: The face with the hole added, or nil if the wire cannot serve as a hole for this
    ///   face — it encloses no area (see #234), or it does not lie inside the face's boundary, so
    ///   neither winding yields a valid face. A degenerate or unusable hole is declined rather than
    ///   returned as an invalid face, which is what breaks callers downstream.
    public static func faceAddHole(face: Shape, wire: Shape) -> Shape? {
        guard let ref = OCCTMakeFaceAddHole(face.handle, wire.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Copy a face.
    public static func faceCopy(_ face: Shape) -> Shape? {
        guard let ref = OCCTMakeFaceCopy(face.handle) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {

    /// Extract the 3D curve from an edge shape. Returns (curve, firstParam, lastParam) or nil.
    public func extractEdgeCurve3D() -> (curve: Curve3D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTEdgeExtractCurve3D(handle, &first, &last) else { return nil }
        return (Curve3D(handle: ref), first, last)
    }

    /// Extract the PCurve of an edge on a face. Returns (curve, firstParam, lastParam) or nil.
    public func extractEdgePCurve(onFace face: Shape) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTEdgeExtractPCurve(handle, face.handle, &first, &last) else { return nil }
        return (Curve2D(handle: ref), first, last)
    }

    /// Get the tolerance of an edge shape.
    public var edgeTolerance: Double { OCCTEdgeGetTolerance(handle) }

    /// Check if an edge is degenerated.
    public var isEdgeDegenerated: Bool { OCCTEdgeIsDegenerated(handle) }

    /// Extract the surface from a face shape.
    public func extractFaceSurface() -> Surface? {
        guard let ref = OCCTFaceExtractSurface(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get the tolerance of a face shape.
    public var faceTolerance: Double { OCCTFaceGetTolerance(handle) }

    /// Get the number of wires on a face shape.
    public var faceWireCount: Int { Int(OCCTFaceWireCount(handle)) }

    /// Get the tolerance of a vertex shape.
    public var vertexTolerance: Double { OCCTVertexGetTolerance(handle) }

    /// Get the point of a vertex shape.
    public var vertexPoint: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTVertexGetPoint(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

extension Shape {

    /// Get the shape type as a string ("compound", "solid", "face", etc.).
    public var shapeTypeString: String {
        guard let cstr = OCCTShapeTypeString(handle) else { return "unknown" }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}

extension Shape {

    /// Get child shape at 0-based index.
    public func child(at index: Int) -> Shape? {
        guard let ref = OCCTShapeChild(handle, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    /// Whether the shape is locked.
    public var isLocked: Bool {
        get { OCCTShapeIsLocked(handle) }
    }

    /// Set locked state on the shape.
    public func setLocked(_ locked: Bool) {
        OCCTShapeSetLocked(handle, locked)
    }

    /// Create a copy with an applied location transform (4x3 row-major matrix).
    public func located(matrix: [Double]) -> Shape? {
        guard matrix.count >= 12 else { return nil }
        guard let ref = matrix.withUnsafeBufferPointer({ buf in
            OCCTShapeLocated(handle, buf.baseAddress!)
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the current location as a 4x3 row-major matrix.
    public var locationMatrix: [Double] {
        var m = [Double](repeating: 0, count: 12)
        OCCTShapeGetLocation(handle, &m)
        return m
    }

    /// Set location transform in-place (4x3 row-major matrix).
    public func setLocation(matrix: [Double]) {
        guard matrix.count >= 12 else { return }
        matrix.withUnsafeBufferPointer { buf in
            OCCTShapeSetLocation(handle, buf.baseAddress!)
        }
    }

    /// Create a shape with specific orientation (0=FWD, 1=REV, 2=INT, 3=EXT).
    public func oriented(_ orientation: Int) -> Shape? {
        guard let ref = OCCTShapeOriented(handle, Int32(orientation)) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty shape of given type (0=COMPOUND, 2=SOLID, 3=SHELL, 5=WIRE).
    public static func empty(type: Int) -> Shape? {
        guard let ref = OCCTShapeEmpty(Int32(type)) else { return nil }
        return Shape(handle: ref)
    }

    /// Whether the shape is a compound.
    public var isCompound: Bool { OCCTShapeIsCompound(handle) }

    /// Whether the shape is a solid.
    public var isSolid: Bool { OCCTShapeIsSolid(handle) }

    /// Whether the shape is a shell.
    public var isShell: Bool { OCCTShapeIsShell(handle) }

    /// Whether the shape is a face.
    public var isFace: Bool { OCCTShapeIsFace(handle) }

    /// Whether the shape is an edge.
    public var isEdge: Bool { OCCTShapeIsEdge(handle) }

    /// Create a wire from an array of edge shapes.
    public static func wireFromEdges(_ edges: [Shape]) -> Shape? {
        let refs = edges.map { $0.handle as OCCTShapeRef }
        guard let ref = refs.withUnsafeBufferPointer({ buf in
            OCCTMakeWireFromEdges(buf.baseAddress!, Int32(edges.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a shell from an array of face shapes.
    public static func shellFromFaces(_ faces: [Shape]) -> Shape? {
        let refs = faces.map { $0.handle as OCCTShapeRef }
        guard let ref = refs.withUnsafeBufferPointer({ buf in
            OCCTMakeShell(buf.baseAddress!, Int32(faces.count))
        }) else { return nil }
        return Shape(handle: ref)
    }

    // --- BRepCheck extended (v0.112.0) ---

    /// Check status of a face within this shape. Returns BRepCheck_Status (0=NoError).
    public func checkFaceStatus(face: Shape) -> Int {
        Int(OCCTCheckFaceStatus(handle, face.handle))
    }

    /// Check status of an edge within this shape.
    public func checkEdgeStatus(edge: Shape) -> Int {
        Int(OCCTCheckEdgeStatus(handle, edge.handle))
    }

    /// Check status of a vertex within this shape.
    public func checkVertexStatus(vertex: Shape) -> Int {
        Int(OCCTCheckVertexStatus(handle, vertex.handle))
    }

    /// Max tolerance of sub-shapes of the given type.
    ///
    /// Additive, ``ShapeType``-typed sibling of the legacy `maxTolerance(type: Int)` overload
    /// below (#833): that overload and ``maxTolerance(subShapeType:)`` each accept a raw `Int`
    /// with a DIFFERENT encoding for the same concept — `maxTolerance(type: 2)` means FACE there,
    /// while `maxTolerance(subShapeType: 2)` means `TopAbs_SOLID` (and silently returns 0, since
    /// `BRep_Tool::MaxTolerance` only handles VERTEX/EDGE/FACE). This overload uses ``ShapeType``,
    /// whose raw values already match the real `TopAbs_ShapeEnum` ordinals `maxTolerance
    /// (subShapeType:)` expects, so both typed and unambiguous entry points now agree.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.maxTolerance(type: .face))
    /// ```
    ///
    /// - Parameter type: Sub-shape type to measure.
    /// - SeeAlso: `maxTolerance(subShapeType:)`, which queries the identical tolerance data via
    ///   `BRep_Tool::MaxTolerance` and already used this same ordinal convention.
    public func maxTolerance(type: ShapeType) -> Double {
        OCCTShapeMaxToleranceOfType(handle, Int32(type.rawValue))
    }

    /// Min tolerance of sub-shapes of the given type. See the `ShapeType`-typed
    /// `maxTolerance(type:)` overload above for why this additive overload exists alongside the
    /// legacy `Int`-based one below (#833).
    public func minTolerance(type: ShapeType) -> Double {
        OCCTShapeMinToleranceOfType(handle, Int32(type.rawValue))
    }

    /// Average tolerance of sub-shapes of the given type. See the `ShapeType`-typed
    /// `maxTolerance(type:)` overload above for why this additive overload exists alongside the
    /// legacy `Int`-based one below (#833).
    public func avgTolerance(type: ShapeType) -> Double {
        OCCTShapeAvgToleranceOfType(handle, Int32(type.rawValue))
    }

    /// Max tolerance of sub-shapes of given type (0=vertex, 1=edge, 2=face).
    ///
    /// - Warning: **Legacy.** This `Int` encoding is compressed and specific to this method —
    ///   `0`/`1`/`2` mean vertex/edge/face here, but `maxTolerance(subShapeType:)` below uses a
    ///   DIFFERENT `Int` convention (real `TopAbs_ShapeEnum` ordinals) for the same idea, so the
    ///   same integer passed to the wrong one silently measures the wrong sub-shape kind (#833).
    ///   Prefer the `ShapeType`-typed `maxTolerance(type:)` overload above, which removes the
    ///   ambiguity. Kept, unchanged, for source compatibility.
    public func maxTolerance(type: Int) -> Double {
        OCCTShapeMaxTolerance(handle, Int32(type))
    }

    /// Min tolerance of sub-shapes of given type.
    ///
    /// - Warning: **Legacy.** Same compressed 0/1/2 encoding as `maxTolerance(type: Int)` above,
    ///   and the same caveat (#833). Prefer the `ShapeType`-typed `minTolerance(type:)` overload
    ///   above.
    public func minTolerance(type: Int) -> Double {
        OCCTShapeMinTolerance(handle, Int32(type))
    }

    /// Average tolerance of sub-shapes of given type.
    ///
    /// - Warning: **Legacy.** Same compressed 0/1/2 encoding as `maxTolerance(type: Int)` above,
    ///   and the same caveat (#833). Prefer the `ShapeType`-typed `avgTolerance(type:)` overload
    ///   above.
    public func avgTolerance(type: Int) -> Double {
        OCCTShapeAvgTolerance(handle, Int32(type))
    }

    /// Fix tolerance on the shape to specified value.
    @discardableResult
    public func fixTolerance(_ tolerance: Double) -> Bool {
        OCCTShapeFixTolerance(handle, tolerance)
    }

    /// Limit max tolerance on the shape.
    @discardableResult
    public func limitMaxTolerance(_ maxTol: Double) -> Bool {
        OCCTShapeLimitMaxTolerance(handle, maxTol)
    }
}

extension Shape {

    /// Create a full ellipse edge.
    ///
    /// - Parameters:
    ///   - center: Ellipse centre.
    ///   - normal: Normal of the plane the ellipse lies in.
    ///   - majorRadius: Major radius. Must be `> 0`.
    ///   - minorRadius: Minor radius. Must be `> 0` and no larger than `majorRadius`.
    /// - Returns: The edge, or `nil` if the radii do not describe an ellipse.
    ///
    /// `BRepBuilderAPI_MakeEdge` reports `IsDone()` for a degenerate conic, so without the radius
    /// check this returned a live edge carrying a curve that is really a point (#554).
    ///
    /// ```swift
    /// let e = Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 5)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromEllipse(majorRadius: 10, minorRadius: 0) == nil)
    /// ```
    public static func edgeFromEllipse(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                        majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromEllipse(center.x, center.y, center.z,
                                                  normal.x, normal.y, normal.z,
                                                  majorRadius, minorRadius) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an ellipse arc edge.
    ///
    /// Same radius contract as `edgeFromEllipse(center:normal:majorRadius:minorRadius:)`.
    ///
    /// ```swift
    /// let e = Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromEllipseArc(majorRadius: 10, minorRadius: 0, u1: 0, u2: .pi) == nil)
    /// ```
    public static func edgeFromEllipseArc(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                           majorRadius: Double, minorRadius: Double,
                                           u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromEllipseArc(center.x, center.y, center.z,
                                                      normal.x, normal.y, normal.z,
                                                      majorRadius, minorRadius, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a hyperbola arc edge.
    ///
    /// Both radii must be `> 0`, with no ordering constraint between them.
    ///
    /// ```swift
    /// let e = Shape.edgeFromHyperbolaArc(majorRadius: 8, minorRadius: 3, u1: 0, u2: 1)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromHyperbolaArc(majorRadius: 8, minorRadius: 0, u1: 0, u2: 1) == nil)
    /// ```
    public static func edgeFromHyperbolaArc(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                             majorRadius: Double, minorRadius: Double,
                                             u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromHyperbolaArc(center.x, center.y, center.z,
                                                        normal.x, normal.y, normal.z,
                                                        majorRadius, minorRadius, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a parabola arc edge.
    ///
    /// `focalLength` must be `> 0`; at zero the parabola is a straight line along its own axis.
    ///
    /// ```swift
    /// let e = Shape.edgeFromParabolaArc(focalLength: 4, u1: 0, u2: 1)
    /// #expect(e != nil)
    /// #expect(Shape.edgeFromParabolaArc(focalLength: 0, u1: 0, u2: 1) == nil)
    /// ```
    public static func edgeFromParabolaArc(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                            focalLength: Double, u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromParabolaArc(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z,
                                                       focalLength, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 3D curve (full domain).
    public static func edgeFromCurve(_ curve: Curve3D) -> Shape? {
        guard let ref = OCCTMakeEdgeFromCurve(curve.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 3D curve with parameter bounds.
    public static func edgeFromCurve(_ curve: Curve3D, u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeFromCurveParams(curve.handle, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 3D curve with point bounds.
    public static func edgeFromCurve(_ curve: Curve3D, from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTMakeEdgeFromCurvePoints(curve.handle, p1.x, p1.y, p1.z,
                                                       p2.x, p2.y, p2.z) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 2D pcurve on a surface (full domain).
    public static func edgeOnSurface(pcurve: Curve2D, surface: Surface) -> Shape? {
        guard let ref = OCCTMakeEdgeOnSurface(pcurve.handle, surface.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create an edge from a 2D pcurve on a surface with parameter bounds.
    public static func edgeOnSurface(pcurve: Curve2D, surface: Surface, u1: Double, u2: Double) -> Shape? {
        guard let ref = OCCTMakeEdgeOnSurfaceParams(pcurve.handle, surface.handle, u1, u2) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the first vertex point of an edge.
    public func edgeVertex1() -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeVertex1(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the last vertex point of an edge.
    public func edgeVertex2() -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeVertex2(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Create a face from a surface with UV bounds and tolerance.
    public static func face(from surface: Surface, uBounds: ClosedRange<Double>, vBounds: ClosedRange<Double>,
                             tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTMakeFaceFromSurfaceUV(surface.handle,
                                                     uBounds.lowerBound, uBounds.upperBound,
                                                     vBounds.lowerBound, vBounds.upperBound, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a gp_Plane with UV bounds.
    ///
    /// Delegates to ``faceFromPlane(origin:normal:uRange:vRange:tolerance:)`` above. The two were
    /// added independently, ~51 releases apart, and always drove the same underlying
    /// `BRepLib_MakeFace` engine — this overload only differed by omitting the `tolerance`
    /// parameter, silently pinning it to whatever `BRepBuilderAPI_MakeFace`'s tolerance-less
    /// constructor hardcodes internally (`Precision::Confusion()`, `1e-7`), which is now this
    /// overload's own default so existing callers see byte-identical geometry (#841).
    ///
    /// - Parameter tolerance: Degeneracy tolerance, forwarded to `BRepLib_MakeFace`. Defaults to
    ///   `Precision::Confusion()` (`1e-7`), matching what this overload silently used before #841.
    public static func faceFromPlane(origin: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0,0,1),
                                      uBounds: ClosedRange<Double>, vBounds: ClosedRange<Double>,
                                      tolerance: Double = 1e-7) -> Shape? {
        faceFromPlane(origin: origin, normal: normal, uRange: uBounds, vRange: vBounds, tolerance: tolerance)
    }

    /// Create a face from a gp_Cylinder with UV bounds.
    ///
    /// Delegates to ``faceFromCylinder(origin:axis:radius:uRange:vRange:tolerance:)`` above — see
    /// that overload's sibling doc comment on ``faceFromPlane(origin:normal:uBounds:vBounds:tolerance:)``
    /// for why (#841).
    ///
    /// - Parameter tolerance: Degeneracy tolerance, forwarded to `BRepLib_MakeFace`. Defaults to
    ///   `Precision::Confusion()` (`1e-7`), matching what this overload silently used before #841.
    public static func faceFromCylinder(origin: SIMD3<Double> = .zero, axis: SIMD3<Double> = SIMD3(0,0,1),
                                         radius: Double,
                                         uBounds: ClosedRange<Double>, vBounds: ClosedRange<Double>,
                                         tolerance: Double = 1e-7) -> Shape? {
        faceFromCylinder(origin: origin, axis: axis, radius: radius, uRange: uBounds, vRange: vBounds, tolerance: tolerance)
    }
}

extension Shape {

    /// Create an empty wire via TopoDS_Builder.
    public static func builderMakeWire() -> Shape? {
        guard let ref = OCCTBuilderMakeWire() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty shell via TopoDS_Builder.
    public static func builderMakeShell() -> Shape? {
        guard let ref = OCCTBuilderMakeShell() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty solid via TopoDS_Builder.
    public static func builderMakeSolid() -> Shape? {
        guard let ref = OCCTBuilderMakeSolid() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty compound via TopoDS_Builder.
    public static func builderMakeCompound() -> Shape? {
        guard let ref = OCCTBuilderMakeCompound() else { return nil }
        return Shape(handle: ref)
    }

    /// Create an empty comp-solid via TopoDS_Builder.
    public static func builderMakeCompSolid() -> Shape? {
        guard let ref = OCCTBuilderMakeCompSolid() else { return nil }
        return Shape(handle: ref)
    }

    /// Add child shape into this shape using TopoDS_Builder.
    @discardableResult
    public func builderAdd(_ child: Shape) -> Bool {
        OCCTBuilderAdd(handle, child.handle)
    }

    /// Remove child shape from this shape using TopoDS_Builder.
    @discardableResult
    public func builderRemove(_ child: Shape) -> Bool {
        OCCTBuilderRemove(handle, child.handle)
    }
}

extension Shape {

    /// Get extended shape contents analysis.
    public func contentsExtended() -> ShapeContentsExtended {
        let c = OCCTShapeGetContentsExtended(handle)
        let core = ShapeContentsCore(c)
        return ShapeContentsExtended(
            nbSolids: core.solids, nbShells: core.shells,
            nbFaces: core.faces, nbWires: core.wires,
            nbEdges: core.edges, nbVertices: core.vertices,
            nbFreeEdges: core.freeEdges, nbFreeWires: core.freeWires,
            nbFreeFaces: core.freeFaces, nbSolidsWithVoids: Int(c.nbSolidsWithVoids),
            nbBigSplines: Int(c.nbBigSplines), nbC0Surfaces: Int(c.nbC0Surfaces),
            nbC0Curves: Int(c.nbC0Curves), nbOffsetSurf: Int(c.nbOffsetSurf),
            nbIndirectSurf: Int(c.nbIndirectSurf), nbOffsetCurves: Int(c.nbOffsetCurves),
            nbTrimmedCurve2d: Int(c.nbTrimmedCurve2d), nbTrimmedCurve3d: Int(c.nbTrimmedCurve3d),
            nbBSplineSurf: Int(c.nbBSplineSurf), nbBezierSurf: Int(c.nbBezierSurf),
            nbTrimSurf: Int(c.nbTrimSurf), nbWireWithSeam: Int(c.nbWireWithSeam),
            nbWireWithSevSeams: Int(c.nbWireWithSevSeams), nbFaceWithSevWires: Int(c.nbFaceWithSevWires),
            nbNoPCurve: Int(c.nbNoPCurve), nbSharedSolids: Int(c.nbSharedSolids),
            nbSharedShells: Int(c.nbSharedShells), nbSharedFaces: Int(c.nbSharedFaces),
            nbSharedWires: Int(c.nbSharedWires), nbSharedEdges: Int(c.nbSharedEdges),
            nbSharedVertices: Int(c.nbSharedVertices)
        )
    }
}

extension Shape {

    /// Create a thick solid by removing faces and offsetting.
    public func thickSolid(facesToRemove: [Shape], offset: Double,
                           tolerance: Double = 1e-3,
                           joinType: OffsetJoinType = .arc) -> Shape? {
        var faceRefs: [OCCTShapeRef] = facesToRemove.map { $0.handle }
        guard let ref = OCCTThickSolidWithOptions(handle, &faceRefs, Int32(faceRefs.count),
                                                    offset, tolerance, joinType.rawValue) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {

    /// Orient a closed solid so that face normals point outward.
    @discardableResult
    public func orientClosedSolid() -> Bool {
        OCCTBRepLibOrientClosedSolid(handle)
    }

    /// Build a 3D curve for every edge of this shape that has only pcurves.
    ///
    /// Edges from a loft, a sweep, or a surface-based face can carry a 2D curve on their support
    /// surface and no 3D curve at all. Anything that walks edge geometry — discretisation, length,
    /// export — needs the 3D curve, so this fills them in. Edges that already have one are left
    /// exactly as they are, so calling it twice costs nothing the second time.
    ///
    /// ```swift
    /// // An edge built from a pcurve on a cylinder has no 3D curve until this runs.
    /// let cylinder = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 10)!
    /// let pcurve = Curve2D.line(through: SIMD2(0.2, -3), direction: SIMD2(0.6, 0.8))!
    /// let edge = Shape.edgeOnSurface(pcurve: pcurve, surface: cylinder, u1: 0, u2: 2)!
    ///
    /// print(edge.extractEdgeCurve3D() == nil)   // true
    /// print(edge.buildCurves3d())               // true
    /// print(edge.extractEdgeCurve3D() != nil)   // true — a BSpline approximating the helix
    /// print(edge.edgeTolerance)                 // 1e-05 — the tolerance lands on the edge
    /// ```
    ///
    /// - Parameter tolerance: Approximation tolerance, and also the rebuilt edge's tolerance floor
    ///   (OCCT sets the edge tolerance to this value, not to the deviation it actually achieved).
    ///   The default is OCCT's own default for the operation. A tighter value buys a closer curve
    ///   for a pole or two more — measured on a helix, `1e-5` deviates from the exact curve by
    ///   2.6e-6 and `1e-7` by 9.0e-8 — but it also claims an edge tolerance the approximation may
    ///   not be able to keep on hard geometry. Ignored when the pcurve lies on a plane: that case
    ///   is analytic and exact.
    /// - Returns: `false` if any single edge could not be given a 3D curve (a degenerate edge with
    ///   no planar pcurve, or one stripped of every representation). The edges that did succeed are
    ///   still modified, so `false` means "partially built", not "nothing happened".
    @discardableResult
    public func buildCurves3d(tolerance: Double = 1e-5) -> Bool {
        OCCTBRepLibBuildCurves3dForShape(handle, tolerance)
    }

    /// Sort faces by decreasing area.
    public func sortedFaces() -> Shape? {
        guard let ref = OCCTBRepLibSortFaces(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Sort faces by increasing area.
    public func reverseSortedFaces() -> Shape? {
        guard let ref = OCCTBRepLibReverseSortFaces(handle) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {

    /// Get the 3D curve from an edge shape with parameter range.
    public func edgeCurveWithParams() -> (curve: Curve3D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTShapeEdgeCurve(handle, &first, &last) else { return nil }
        return (Curve3D(handle: ref), first, last)
    }

    /// Get the surface from a face shape.
    public func faceSurfaceGeom() -> Surface? {
        guard let ref = OCCTShapeFaceSurface(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Whether this shape is closed (wire or shell).
    public var isClosedShape: Bool { OCCTShapeIsClosed(handle) }
}

// Older spellings of the counts on `subShapeCount(ofType:)`, kept because they are public. The
// "unique" in the name is not a distinction: every sub-shape count in this API reads the one
// deduplicated enumeration, so these agree with `edgeCount`, `faceCount`, `vertexCount` and
// `subShapeCount(ofType:)` by construction rather than by coincidence. (#502)
extension Shape {

    /// Number of unique edges in this shape. Same value as ``edgeCount``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.uniqueEdgeCount == box.edgeCount)   // true, 12 either way
    /// ```
    public var uniqueEdgeCount: Int { Int(OCCTShapeUniqueEdgeCount(handle)) }

    /// Number of unique faces in this shape. Same value as ``faceCount``.
    public var uniqueFaceCount: Int { Int(OCCTShapeUniqueFaceCount(handle)) }

    /// Number of unique vertices in this shape. Same value as ``vertexCount``.
    public var uniqueVertexCount: Int { Int(OCCTShapeUniqueVertexCount(handle)) }

    /// Count unique sub-shapes of a specific type. Same value as ``subShapeCount(ofType:)``.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.uniqueSubShapeCount(ofType: .wire))   // 6
    /// ```
    public func uniqueSubShapeCount(ofType type: ShapeType) -> Int {
        Int(OCCTShapeUniqueSubShapeCount(handle, Int32(type.rawValue)))
    }
}

extension Shape {

    /// Create an empty copy of this shape (same TShape, no sub-shapes).
    public func emptyCopied() -> Shape? {
        guard let ref = OCCTShapeEmptyCopied(handle) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Find the common vertex between two edges.
    public static func commonVertex(edge1: Shape, edge2: Shape) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        if OCCTEdgesCommonVertex(edge1.handle, edge2.handle, &x, &y, &z) {
            return SIMD3(x, y, z)
        }
        return nil
    }
}

extension Shape {
    /// Check if edge has SameParameter flag (3D curve matches pcurves parametrically).
    public var edgeSameParameter: Bool {
        OCCTEdgeSameParameter(handle)
    }

    /// Check if edge has SameRange flag (all representations share the same range).
    public var edgeSameRange: Bool {
        OCCTEdgeSameRange(handle)
    }

    /// Check if face has NaturalRestriction (bounded by its own parametric bounds).
    public var faceNaturalRestriction: Bool {
        OCCTFaceNaturalRestriction(handle)
    }

    /// Check if edge has geometric representation (3D curve or curve on surface).
    public var edgeIsGeometric: Bool {
        OCCTEdgeIsGeometric(handle)
    }

    /// Check if face has geometric representation (underlying surface).
    public var faceIsGeometric: Bool {
        OCCTFaceIsGeometric(handle)
    }
}

extension Shape {
    /// Serialize this shape to a BREP format string.
    public func toBREPString() -> String? {
        guard let cstr = OCCTShapeToBREPString(handle) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }

    /// Deserialize a shape from a BREP format string.
    public static func fromBREPString(_ brep: String) -> Shape? {
        guard let ref = OCCTShapeFromBREPString(brep) else { return nil }
        return Shape(handle: ref)
    }
}

extension Shape {
    /// Remove triangulation from this shape (BRepTools::Clean).
    public func cleanTriangulation() {
        OCCTBRepToolsCleanTriangulation(handle)
    }

    /// Remove internal edges/vertices from this shape (BRepTools::RemoveInternals).
    public func removeInternals() {
        OCCTBRepToolsRemoveInternals(handle)
    }

    /// Detect if this face is closed in U and/or V.
    /// Returns (isClosedU, isClosedV).
    public func detectClosedness() -> (isClosedU: Bool, isClosedV: Bool) {
        var u = false, v = false
        OCCTBRepToolsDetectClosedness(handle, &u, &v)
        return (u, v)
    }

    /// Evaluate and update tolerance of an edge on a face. Returns the new tolerance.
    public static func evalAndUpdateTolerance(edge: Shape, face: Shape) -> Double {
        OCCTBRepToolsEvalAndUpdateTol(edge.handle, face.handle)
    }

    /// Count 3D edges in this shape.
    public var map3DEdgeCount: Int {
        Int(OCCTBRepToolsMap3DEdgeCount(handle))
    }

    /// Update face UV points.
    public func updateFaceUVPoints() {
        OCCTBRepToolsUpdateFaceUVPoints(handle)
    }

    /// Compare two vertices for geometric equality.
    public static func compareVertices(_ v1: Shape, _ v2: Shape) -> Bool {
        OCCTBRepToolsCompareVertices(v1.handle, v2.handle)
    }

    /// Compare two edges for geometric equality.
    public static func compareEdges(_ e1: Shape, _ e2: Shape) -> Bool {
        OCCTBRepToolsCompareEdges(e1.handle, e2.handle)
    }

    /// Check if an edge is really closed on a face.
    public static func isReallyClosed(edge: Shape, face: Shape) -> Bool {
        OCCTBRepToolsIsReallyClosed(edge.handle, face.handle)
    }

    /// Update a shape topology (BRepTools::Update).
    public func updateTopology() {
        OCCTBRepToolsUpdate(handle)
    }
}

extension Shape {
    /// Ensure normal consistency of triangulated shape. Returns true if normals were fixed.
    @discardableResult
    public func ensureNormalConsistency(maxAngle: Double = 0.001) -> Bool {
        OCCTBRepLibEnsureNormalConsistency(handle, maxAngle)
    }

    /// Update deflection information of this shape.
    public func updateDeflection() {
        OCCTBRepLibUpdateDeflection(handle)
    }

    /// The continuity of the surface across an edge between two faces.
    ///
    /// A sharp join reports ``ContinuityClass/c0``, a fillet's tangent join
    /// ``ContinuityClass/g1``, and a seam edge on an elementary surface (a cylinder's or
    /// sphere's) ``ContinuityClass/cN`` — `BRepLib::ContinuityOfFaces` short-circuits to CN for
    /// those, and promotes any elementary pair that measures C2 to CN as well. ``ContinuityClass/c3``
    /// is the one class it never returns.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let faces = box.faces(), edges = box.edges()
    /// Shape.continuityClassOfFaces(edge: edges[0], face1: faces[0], face2: faces[1])  // .c0
    /// ```
    ///
    /// - Returns: The measured class, or nil if the arguments are not an edge and two faces that
    ///   share it (OCCT throwing, or a null handle).
    public static func continuityClassOfFaces(edge: Shape, face1: Shape, face2: Shape,
                                              tolerance: Double = 1e-6) -> ContinuityClass? {
        ContinuityClass(rawValue:
            OCCTBRepLibContinuityOfFaces(edge.handle, face1.handle, face2.handle, tolerance))
    }

    /// Same-parameter all edges in a shape.
    public func sameParameterAll(tolerance: Double = 1e-5, forced: Bool = false) {
        OCCTBRepLibSameParameterAll(handle, tolerance, forced)
    }
}

extension Shape {
    /// Get a nullified copy of the shape.
    public var nullified: Shape? {
        guard let h = OCCTShapeNullified(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get the shape type as a string name.
    public var typeName: String? {
        guard let cstr = OCCTShapeTypeName(handle) else { return nil }
        return String(cString: cstr)
    }

    /// Check if this shape is NOT equal to another.
    public func isNotEqual(to other: Shape) -> Bool {
        OCCTShapeIsNotEqual(handle, other.handle)
    }

    /// Get an emptied copy of the shape (no sub-shapes).
    public var emptied: Shape? {
        guard let h = OCCTShapeEmptied(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Move the shape by a translation vector. Returns a new shape.
    public func moved(dx: Double, dy: Double, dz: Double) -> Shape? {
        guard let h = OCCTShapeMoved(handle, dx, dy, dz) else { return nil }
        return Shape(handle: h)
    }

    /// Get the orientation value as integer (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
    public var orientationValue: Int {
        Int(OCCTShapeOrientationValue(handle))
    }

}
