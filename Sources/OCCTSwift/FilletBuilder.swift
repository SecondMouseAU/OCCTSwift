import OCCTBridge
import OCCTPlatform

/// Builder for creating fillets on edges of a shape, wrapping BRepFilletAPI_MakeFillet.
///
/// ## Finding a declined edge (#639)
///
/// `addEdge` returns `true` even for an edge OCCT goes on to silently decline: a free-boundary
/// edge of an open shell, most commonly, which has only one adjacent face where a fillet needs
/// two. Unlike the free functions (``Shape/filleted(edges:radius:)`` and siblings), this class
/// already has the query for it: ``contour(for:)`` returns `0` for an edge that never entered any
/// contour, populated by `Add()` itself so it is readable right after `addEdge`, with no need to
/// call ``build()`` first.
///
/// ```swift
/// let box = Shape.box(width: 10, height: 10, depth: 10)!
/// let faces = box.faces().dropFirst().compactMap { Shape.fromFace($0) }
/// let shell = Shape.sew(shapes: Array(faces))!       // an open shell: some edges are unfilletable
/// let builder = FilletBuilder(shape: shell)!
/// let edges = shell.edges()
/// for edge in edges { builder.addEdge(edge, radius: 1.0) }
/// let declined = edges.filter { builder.contour(for: $0) == 0 }
/// print(declined.map(\.index))   // e.g. [6, 9, 10, 11]
/// ```
///
/// ## Contour and edge indices (#3518)
///
/// Every method that takes a contour index takes it 1-based, in `1...contourCount`; the edge index
/// inside a contour is `1...edgeCount(contour:)`. An index outside its range, `0` and the negatives
/// included, is refused with the answer each method documents (`0`, `-1`, `false`, `nil` or no
/// effect) and never reaches the kernel. OCCT range-checks neither end reliably: an index past the
/// end, or any index on a builder with no contour, faulted the process uncatchably, and `0` or a
/// negative read, or wrote, contour 1.
///
/// ```swift
/// let box = Shape.box(width: 10, height: 10, depth: 10)!
/// let builder = FilletBuilder(shape: box)!
/// print(builder.edgeCount(contour: 1))        // 0: no contour yet, and not a crash
/// builder.addEdge(box.edges()[0], radius: 1)
/// print(builder.edgeCount(contour: 1))        // 1
/// print(builder.edgeCount(contour: 0))        // 0, not contour 1
/// print(builder.edgeCount(contour: 2))        // 0
/// ```
public final class FilletBuilder: @unchecked Sendable {
    private let handle: OCCTFilletBuilderRef
    private let input: Shape

    /// Create a fillet builder on the given shape.
    public init?(shape: Shape) {
        guard let ref = OCCTFilletBuilderCreate(shape.handle) else { return nil }
        self.handle = ref
        self.input = shape
    }

    deinit { OCCTFilletBuilderRelease(handle) }

    /// Add an edge with constant fillet radius.
    @discardableResult
    public func addEdge(_ edge: Edge, radius: Double) -> Bool {
        OCCTFilletBuilderAddEdge(handle, edge.handle, radius)
    }

    /// Add an edge with evolving fillet radius (r1 at start, r2 at end).
    @discardableResult
    public func addEdge(_ edge: Edge, radius1: Double, radius2: Double) -> Bool {
        OCCTFilletBuilderAddEdgeEvolving(handle, edge.handle, radius1, radius2)
    }

    /// Build the filleted result.
    ///
    /// Answers nil when the builder is not done, and also when it is done but the result is
    /// `BRepCheck`-invalid (#3200), has a different solid count than the input, or is the input
    /// unchanged (#3297, #3298); ``hasResult``, ``faultyContourCount`` and ``faultyVertexCount``
    /// are the builder's own diagnostics and are not changed by that.
    public func build() -> Shape? {
        guard let ref = OCCTFilletBuilderBuild(handle) else { return nil }
        let result = Shape(handle: ref)
        guard OCCTBlendResultIsSane(input.handle, result.handle) else { return nil }
        return result
    }

    /// Number of contours.
    public var contourCount: Int { Int(OCCTFilletBuilderNbContours(handle)) }

    /// Number of edges in a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`. An index outside that
    ///   range, `0` and the negatives included, answers `0` (#3518).
    /// - Returns: The number of edges in the contour, or `0` for a contour that does not exist.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.edgeCount(contour: 1))   // 1
    /// print(builder.edgeCount(contour: 2))   // 0: past contourCount, not a crash
    /// ```
    public func edgeCount(contour: Int) -> Int {
        Int(OCCTFilletBuilderNbEdges(handle, Int32(clamping: contour)))
    }

    /// Whether the builder has a result (may be partial).
    public var hasResult: Bool { OCCTFilletBuilderHasResult(handle) }

    /// Get the shape that caused failure (if any).
    public var badShape: Shape? {
        guard let ref = OCCTFilletBuilderBadShape(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Number of faulty contours.
    public var faultyContourCount: Int { Int(OCCTFilletBuilderNbFaultyContours(handle)) }

    /// Number of faulty vertices.
    public var faultyVertexCount: Int { Int(OCCTFilletBuilderNbFaultyVertices(handle)) }

    /// Get the radius of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The radius, or `-1` for a contour that does not exist, the value OCCT documents
    ///   for an index outside its table. `0` and the negatives used to answer contour 1 (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.radius(contour: 1))   // 1.0
    /// print(builder.radius(contour: 0))   // -1.0, not contour 1
    /// ```
    public func radius(contour: Int) -> Double {
        OCCTFilletBuilderGetRadius(handle, Int32(clamping: contour))
    }

    /// Get the length of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The length, or `-1` for a contour that does not exist, the value OCCT documents
    ///   for an index outside its table. `0` and the negatives used to answer contour 1 (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.length(contour: 1))   // 10.0
    /// print(builder.length(contour: 2))   // -1.0
    /// ```
    public func length(contour: Int) -> Double {
        OCCTFilletBuilderGetLength(handle, Int32(clamping: contour))
    }

    /// Whether a contour has a constant radius.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: `true` for a constant radius, `false` otherwise, and `false` for a contour that
    ///   does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.isConstant(contour: 1))   // true
    /// print(builder.isConstant(contour: 2))   // false: no such contour
    /// ```
    public func isConstant(contour: Int) -> Bool {
        OCCTFilletBuilderIsConstant(handle, Int32(clamping: contour))
    }

    /// Remove an edge from its contour.
    @discardableResult
    public func removeEdge(_ edge: Edge) -> Bool {
        OCCTFilletBuilderRemoveEdge(handle, edge.handle)
    }

    /// Reset all contours.
    public func reset() {
        OCCTFilletBuilderReset(handle)
    }
}

extension FilletBuilder {
    /// Set the radius on a specific edge in a contour.
    ///
    /// - Parameters:
    ///   - radius: The new radius.
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - edge: An edge the contour holds.
    /// - Returns: `false`, and changes nothing, for a contour that does not exist. `0` and the
    ///   negatives used to re-radius contour 1, and an index past the end answered `true` for a
    ///   write that never happened (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// let edge = box.edges()[0]
    /// builder.addEdge(edge, radius: 1)
    /// print(builder.setRadius(2, contour: 1, edge: edge))   // true
    /// print(builder.setRadius(2, contour: 0, edge: edge))   // false: no contour 0
    /// ```
    @discardableResult
    public func setRadius(_ radius: Double, contour: Int, edge: Edge) -> Bool {
        OCCTFilletBuilderSetRadiusOnEdge(handle, radius, Int32(clamping: contour), edge.handle)
    }

    /// Set the radius at a specific vertex in a contour.
    ///
    /// - Parameters:
    ///   - radius: The radius at the vertex.
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - vertex: A vertex of the contour.
    /// - Returns: `false`, and changes nothing, for a contour that does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// let vertex = builder.firstVertex(contour: 1)!
    /// print(builder.setRadius(2, contour: 5, vertex: vertex))   // false: no contour 5
    /// ```
    @discardableResult
    public func setRadius(_ radius: Double, contour: Int, vertex: Shape) -> Bool {
        OCCTFilletBuilderSetRadiusAtVertex(handle, radius, Int32(clamping: contour), vertex.handle)
    }

    /// Set two radii (evolving) on a contour edge.
    ///
    /// - Parameters:
    ///   - r1: The radius at the start of the edge.
    ///   - r2: The radius at its end.
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - edgeInContour: The 1-based position of the edge inside the contour,
    ///     `1...edgeCount(contour:)`. `0` is not an edge: OCCT reads it as an absolute abscissa.
    /// - Returns: `false`, and changes nothing, when either index is outside its range (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.setTwoRadii(1, 3, contour: 1, edgeInContour: 1))   // true
    /// print(builder.setTwoRadii(1, 3, contour: 1, edgeInContour: 2))   // false: one edge only
    /// ```
    @discardableResult
    public func setTwoRadii(_ r1: Double, _ r2: Double, contour: Int, edgeInContour: Int) -> Bool {
        OCCTFilletBuilderSetTwoRadii(
            handle, r1, r2, Int32(clamping: contour), Int32(clamping: edgeInContour))
    }

    /// Get contour index for an edge (0 if not found).
    ///
    /// `0` covers two different things a caller may need to tell apart: an edge never passed to
    /// ``addEdge(_:radius:)``/``addEdge(_:radius1:radius2:)`` at all, and one that was but that
    /// OCCT declined (#639, see the type's own doc). This only distinguishes them for edges the
    /// caller itself tracked as added.
    public func contour(for edge: Edge) -> Int {
        Int(OCCTFilletBuilderContour(handle, edge.handle))
    }

    /// Get edge `index` in a contour.
    ///
    /// - Parameters:
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - index: The 1-based position of the edge inside the contour, `1...edgeCount(contour:)`.
    /// - Returns: The edge, or `nil` when either index is outside its range (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.edge(contour: 1, index: 1) != nil)   // true
    /// print(builder.edge(contour: 1, index: 2) != nil)   // false: the contour holds one edge
    /// print(builder.edge(contour: 2, index: 1) != nil)   // false: no second contour
    /// ```
    public func edge(contour: Int, index: Int) -> Shape? {
        guard
            let ref = OCCTFilletBuilderEdge(
                handle, Int32(clamping: contour), Int32(clamping: index))
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// First vertex of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The vertex, or `nil` for a contour that does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.firstVertex(contour: 1) != nil)   // true
    /// print(builder.firstVertex(contour: 0) != nil)   // false
    /// ```
    public func firstVertex(contour: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderFirstVertex(handle, Int32(clamping: contour)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Last vertex of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The vertex, or `nil` for a contour that does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.lastVertex(contour: 1) != nil)   // true
    /// print(builder.lastVertex(contour: 2) != nil)   // false
    /// ```
    public func lastVertex(contour: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderLastVertex(handle, Int32(clamping: contour)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Curvilinear abscissa of a vertex on a contour.
    ///
    /// - Parameters:
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - vertex: A vertex of the contour.
    /// - Returns: The abscissa, or `-1` for a contour that does not exist, the value OCCT
    ///   documents for an index outside its table (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// let end = builder.lastVertex(contour: 1)!
    /// print(builder.abscissa(contour: 1, vertex: end))   // 10.0
    /// print(builder.abscissa(contour: 0, vertex: end))   // -1.0
    /// ```
    public func abscissa(contour: Int, vertex: Shape) -> Double {
        OCCTFilletBuilderAbscissa(handle, Int32(clamping: contour), vertex.handle)
    }

    /// Relative abscissa (0 to 1) of a vertex on a contour.
    ///
    /// - Parameters:
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - vertex: A vertex of the contour.
    /// - Returns: The relative abscissa, or `-1` for a contour that does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// let end = builder.lastVertex(contour: 1)!
    /// print(builder.relativeAbscissa(contour: 1, vertex: end))   // 1.0
    /// print(builder.relativeAbscissa(contour: 2, vertex: end))   // -1.0
    /// ```
    public func relativeAbscissa(contour: Int, vertex: Shape) -> Double {
        OCCTFilletBuilderRelativeAbscissa(handle, Int32(clamping: contour), vertex.handle)
    }

    /// Whether a contour is closed and tangent at closure.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.isClosedAndTangent(contour: 1))   // false: one open edge
    /// print(builder.isClosedAndTangent(contour: 9))   // false: no such contour
    /// ```
    public func isClosedAndTangent(contour: Int) -> Bool {
        OCCTFilletBuilderClosedAndTangent(handle, Int32(clamping: contour))
    }

    /// Whether a contour is closed.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.isClosed(contour: 1))   // false: one open edge
    /// print(builder.isClosed(contour: 0))   // false: no such contour
    /// ```
    public func isClosed(contour: Int) -> Bool {
        OCCTFilletBuilderClosed(handle, Int32(clamping: contour))
    }

    /// Number of surfaces after build.
    ///
    /// Answers `0` unless the last ``build()`` completed: the builder was never built, the build
    /// was declined (``faultyContourCount`` says how many contours the kernel refused), there was
    /// no contour to build, or ``reset()`` has been called since. OCCT reads this count from a
    /// data structure that exists only once a build got that far, and reading it on any of those
    /// builders used to fault the process uncatchably (#3516).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.edges()[0]
    ///
    /// let declined = FilletBuilder(shape: box)!
    /// declined.addEdge(edge, radius: 20)           // far past half a face width
    /// _ = declined.build()                         // nil: the builder refused it
    /// print(declined.surfaceCount)                 // 0, and faultyContourCount is 1
    ///
    /// let built = FilletBuilder(shape: box)!
    /// built.addEdge(edge, radius: 1)
    /// _ = built.build()                            // the filleted box
    /// print(built.surfaceCount)                    // 2
    /// ```
    public var surfaceCount: Int { Int(OCCTFilletBuilderNbSurfaces(handle)) }

    /// Number of computed surfaces for a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`. OCCT already refused
    ///   an index outside that range here; only the conversion to a C integer is new (#3518).
    /// - Returns: The number of computed surfaces, or `0` for a contour that does not exist.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// _ = builder.build()
    /// print(builder.computedSurfaceCount(contour: 1))   // 1
    /// print(builder.computedSurfaceCount(contour: 2))   // 0
    /// ```
    public func computedSurfaceCount(contour: Int) -> Int {
        Int(OCCTFilletBuilderNbComputedSurfaces(handle, Int32(clamping: contour)))
    }

    /// Error status for a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The `ChFiDS_ErrorStatus` as an `Int` (`0` is ok), or `-1` for a contour that
    ///   does not exist. OCCT dereferences the contour it failed to find, so any index outside
    ///   the range faulted the process before #3518.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// print(builder.stripeStatus(contour: 1))   // 0
    /// print(builder.stripeStatus(contour: 2))   // -1: past contourCount, not a crash
    /// ```
    public func stripeStatus(contour: Int) -> Int {
        Int(OCCTFilletBuilderStripeStatus(handle, Int32(clamping: contour)))
    }

    /// Get the faulty contour index for the i-th fault (1-based, `1...faultyContourCount`).
    ///
    /// An index outside that range answers `0`.
    public func faultyContour(index: Int) -> Int {
        Int(OCCTFilletBuilderFaultyContour(handle, Int32(clamping: index)))
    }

    /// Get the faulty vertex for the i-th fault (1-based, `1...faultyVertexCount`).
    ///
    /// An index outside that range answers `nil`.
    public func faultyVertex(index: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderFaultyVertex(handle, Int32(clamping: index)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - FilletBuilder completions (v0.126.0)

    /// Set fillet tolerances.
    ///
    /// All six must be finite and positive. Otherwise the call changes nothing and the previous
    /// tolerances stay in force: a zero or negative `tApp3d` crashes ``build()`` uncatchably, so
    /// such values are refused here rather than stored.
    public func setParams(
        tang: Double, tesp: Double, t2d: Double,
        tApp3d: Double, tApp2d: Double, fleche: Double
    ) {
        OCCTFilletBuilderSetParams(handle, tang, tesp, t2d, tApp3d, tApp2d, fleche)
    }

    /// Set the internal continuity of the generated fillet surfaces.
    ///
    /// `internalContinuity` is a ``ParametricContinuity`` raw value; OCCT's own domain here is
    /// "a continuity Ci (i=0, 1 or 2)", default C1. The bridge used to cast the integer straight
    /// to `GeomAbs_Shape`, which made `1` mean G1 and `2` mean C1, one class below what this
    /// comment promised, from 1 up (#490).
    ///
    /// ```swift
    /// builder.setContinuity(2, angularTolerance: 1e-4)  // C2 fillet surfaces
    /// ```
    public func setContinuity(_ internalContinuity: Int, angularTolerance: Double) {
        OCCTFilletBuilderSetContinuity(handle, Int32(internalContinuity), angularTolerance)
    }

    /// Set fillet shape type: 0=Rational, 1=QuasiAngular, 2=Polynomial.
    public func setFilletShape(_ filletShape: Int) {
        OCCTFilletBuilderSetFilletShape(handle, Int32(filletShape))
    }

    /// Get fillet shape type: 0=Rational, 1=QuasiAngular, 2=Polynomial.
    public var filletShape: Int {
        Int(OCCTFilletBuilderGetFilletShape(handle))
    }

    /// Reset the radius info of one contour.
    ///
    /// - Parameter contourIndex: The 1-based contour index, `1...contourCount`. An index outside
    ///   that range does nothing; `0` and the negatives used to reset contour 1 (#3518).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    /// builder.resetContour(0)             // no contour 0: contour 1 keeps its radius
    /// print(builder.radius(contour: 1))   // 1.0
    /// ```
    public func resetContour(_ contourIndex: Int) {
        OCCTFilletBuilderResetContour(handle, Int32(clamping: contourIndex))
    }

    /// Simulate filleting on a contour (computes sections without building).
    ///
    /// An index outside `1...contourCount` does nothing: OCCT walks its contour list for the
    /// index and finds none.
    public func simulate(contour: Int) {
        OCCTFilletBuilderSimulate(handle, Int32(clamping: contour))
    }

    /// Get the number of simulated surfaces for a contour (1-based).
    ///
    /// Answers `0` while the contour holds no surface data: the builder was never built or
    /// simulated, ``reset()`` has been called since, the simulation was declined, or `contour`
    /// names no contour. OCCT reads this count from a sequence that only ``build()`` or
    /// ``simulate(contour:)`` creates for a contour, and reading it before either had run, or after
    /// a reset, used to fault the process uncatchably (#3519). A contour that ``build()`` has run on
    /// keeps the surface count that build left.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = FilletBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], radius: 1)
    ///
    /// print(builder.simulatedSurfaceCount(contour: 1))   // 0: nothing has run on it yet
    /// builder.simulate(contour: 1)
    /// print(builder.simulatedSurfaceCount(contour: 1))   // 1: one fillet face on a box edge
    /// builder.reset()
    /// print(builder.simulatedSurfaceCount(contour: 1))   // 0: reset discards the surface data
    /// ```
    public func simulatedSurfaceCount(contour: Int) -> Int {
        Int(OCCTFilletBuilderNbSimulatedSurf(handle, Int32(contour)))
    }
}

extension FilletBuilder {

    /// Parameter bounds of the radius law on one edge of a contour.
    ///
    /// The range is the contour's own spine parameterisation, not the edge's: it runs past the
    /// edge's ends once the fillet is built, because the blend surface extends beyond the edge it
    /// was asked for.
    ///
    /// Returns `nil` when there is no law to measure, which covers four cases:
    /// `contour` is outside `1...contourCount`; the contour does not hold `edge` (an edge from
    /// another contour counts, and used to be answered about anyway, #505); the contour's spine has
    /// not been split yet, which `build()` and ``FilletBuilder/simulate(contour:)`` both do; or the
    /// radius is constant along the contour, which OCCT represents as no law rather than a flat one.
    ///
    /// - Parameters:
    ///   - contour: Contour index (1-based)
    ///   - edge: An edge the contour holds
    /// - Returns: Parameter range `(first, last)`, or `nil`
    ///
    /// ```swift
    /// let builder = FilletBuilder(shape: box)!
    /// let edge = box.edges()[0]
    /// builder.addEdge(edge, radius1: 0.5, radius2: 2.0)   // evolving: there is a law
    /// _ = builder.build()
    /// if let bounds = builder.getBounds(contour: 1, edge: edge) {
    ///     print(bounds.first, bounds.last)
    /// }
    /// ```
    public func getBounds(contour: Int, edge: Edge) -> (first: Double, last: Double)? {
        var first = 0.0
        var last = 0.0
        guard
            OCCTFilletBuilderGetBounds(
                handle, Int32(clamping: contour), edge.handle, &first, &last)
        else {
            return nil
        }
        return (first, last)
    }

    /// The radius law on one edge of a contour.
    ///
    /// Returns `nil` in the same four cases as ``FilletBuilder/getBounds(contour:edge:)``. In
    /// particular a constant-radius contour has no law, so ask ``FilletBuilder/isConstant(contour:)``
    /// first if the radius did not come from ``FilletBuilder/addEdge(_:radius1:radius2:)``.
    ///
    /// - Parameters:
    ///   - contour: Contour index (1-based)
    ///   - edge: An edge the contour holds
    /// - Returns: The law function, or `nil`
    ///
    /// ```swift
    /// if let law = builder.getLaw(contour: 1, edge: edge) {
    ///     print(law.value(at: law.bounds.lowerBound))   // 0.5, the radius at the start
    /// }
    /// ```
    public func getLaw(contour: Int, edge: Edge) -> LawFunction? {
        guard let ref = OCCTFilletBuilderGetLaw(handle, Int32(clamping: contour), edge.handle)
        else {
            return nil
        }
        return LawFunction(handle: ref)
    }

    /// Set the radius law on one edge of a contour.
    ///
    /// Rejected, returning `false`, in the same four cases as
    /// ``FilletBuilder/getBounds(contour:edge:)``: no such contour, an edge the contour does not
    /// hold, no spine split yet, or a constant-radius contour.
    ///
    /// The law is what ``FilletBuilder/getLaw(contour:edge:)`` reads back afterwards. It does not
    /// reach the geometry: measured against the pinned kernel, a `build()` after this call reports
    /// success and hands back the *unfilleted* input shape
    /// (`Scripts/repro/505-filletbuilder-edge-type/`), so treat this as editing the builder's
    /// recorded law rather than as a way to reshape an already-built fillet.
    ///
    /// - Parameters:
    ///   - contour: Contour index (1-based)
    ///   - edge: An edge the contour holds
    ///   - law: The radius law, over the range ``FilletBuilder/getBounds(contour:edge:)`` reports
    /// - Returns: `true` if the law was set
    ///
    /// ```swift
    /// let bounds = builder.getBounds(contour: 1, edge: edge)!
    /// let law = LawFunction.linear(from: 4, to: 4, parameterRange: bounds.first...bounds.last)!
    /// builder.setLaw(contour: 1, edge: edge, law: law)
    /// builder.getLaw(contour: 1, edge: edge)?.value(at: bounds.first)   // 4.0
    /// ```
    @discardableResult
    public func setLaw(contour: Int, edge: Edge, law: LawFunction) -> Bool {
        OCCTFilletBuilderSetLaw(handle, Int32(clamping: contour), edge.handle, law.handle)
    }

    /// Get shapes generated from an input shape by the fillet operation.
    ///
    /// The fillet must be built first.
    /// - Parameter shape: The input shape (typically an edge)
    /// - Returns: Array of generated shapes
    public func generated(from shape: Shape) -> [Shape] {
        var shapesPtr: UnsafeMutablePointer<OCCTShapeRef?>?
        let count = OCCTFilletBuilderGenerated(handle, shape.handle, &shapesPtr)
        guard count > 0, let shapes = shapesPtr else { return [] }
        defer { free(shapes) }
        var result = [Shape]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = shapes[i] {
                result.append(Shape(handle: ref))
            }
        }
        return result
    }

    /// Get shapes modified from an input shape by the fillet operation.
    ///
    /// The fillet must be built first.
    /// - Parameter shape: The input shape (typically a face)
    /// - Returns: Array of modified shapes
    public func modified(from shape: Shape) -> [Shape] {
        var shapesPtr: UnsafeMutablePointer<OCCTShapeRef?>?
        let count = OCCTFilletBuilderModified(handle, shape.handle, &shapesPtr)
        guard count > 0, let shapes = shapesPtr else { return [] }
        defer { free(shapes) }
        var result = [Shape]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = shapes[i] {
                result.append(Shape(handle: ref))
            }
        }
        return result
    }

    /// Check if a shape was deleted by the fillet operation.
    ///
    /// The fillet must be built first.
    /// - Parameter shape: The input shape
    /// - Returns: true if the shape was deleted
    public func isDeleted(_ shape: Shape) -> Bool {
        OCCTFilletBuilderIsDeleted(handle, shape.handle)
    }
}
