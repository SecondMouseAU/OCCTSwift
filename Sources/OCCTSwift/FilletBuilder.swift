import Foundation
import simd
import OCCTBridge

/// Builder for creating fillets on edges of a shape, wrapping BRepFilletAPI_MakeFillet.
public final class FilletBuilder: @unchecked Sendable {
    private let handle: OCCTFilletBuilderRef

    /// Create a fillet builder on the given shape.
    public init?(shape: Shape) {
        guard let ref = OCCTFilletBuilderCreate(shape.handle) else { return nil }
        self.handle = ref
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
    public func build() -> Shape? {
        guard let ref = OCCTFilletBuilderBuild(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Number of contours.
    public var contourCount: Int { Int(OCCTFilletBuilderNbContours(handle)) }

    /// Number of edges in a contour (1-based index).
    public func edgeCount(contour: Int) -> Int {
        Int(OCCTFilletBuilderNbEdges(handle, Int32(contour)))
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

    /// Get radius of a contour (1-based index).
    public func radius(contour: Int) -> Double {
        OCCTFilletBuilderGetRadius(handle, Int32(contour))
    }

    /// Get length of a contour (1-based index).
    public func length(contour: Int) -> Double {
        OCCTFilletBuilderGetLength(handle, Int32(contour))
    }

    /// Whether a contour has constant radius (1-based index).
    public func isConstant(contour: Int) -> Bool {
        OCCTFilletBuilderIsConstant(handle, Int32(contour))
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
    /// Set radius on a specific edge in a contour.
    @discardableResult
    public func setRadius(_ radius: Double, contour: Int, edge: Edge) -> Bool {
        OCCTFilletBuilderSetRadiusOnEdge(handle, radius, Int32(contour), edge.handle)
    }

    /// Set radius at a specific vertex in a contour.
    @discardableResult
    public func setRadius(_ radius: Double, contour: Int, vertex: Shape) -> Bool {
        OCCTFilletBuilderSetRadiusAtVertex(handle, radius, Int32(contour), vertex.handle)
    }

    /// Set two radii (evolving) on a contour edge.
    @discardableResult
    public func setTwoRadii(_ r1: Double, _ r2: Double, contour: Int, edgeInContour: Int) -> Bool {
        OCCTFilletBuilderSetTwoRadii(handle, r1, r2, Int32(contour), Int32(edgeInContour))
    }

    /// Get contour index for an edge (0 if not found).
    public func contour(for edge: Edge) -> Int {
        Int(OCCTFilletBuilderContour(handle, edge.handle))
    }

    /// Get edge J in contour I (both 1-based).
    public func edge(contour: Int, index: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderEdge(handle, Int32(contour), Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    /// First vertex of contour (1-based).
    public func firstVertex(contour: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderFirstVertex(handle, Int32(contour)) else { return nil }
        return Shape(handle: ref)
    }

    /// Last vertex of contour (1-based).
    public func lastVertex(contour: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderLastVertex(handle, Int32(contour)) else { return nil }
        return Shape(handle: ref)
    }

    /// Curvilinear abscissa of vertex on contour (1-based).
    public func abscissa(contour: Int, vertex: Shape) -> Double {
        OCCTFilletBuilderAbscissa(handle, Int32(contour), vertex.handle)
    }

    /// Relative abscissa (0..1) of vertex on contour (1-based).
    public func relativeAbscissa(contour: Int, vertex: Shape) -> Double {
        OCCTFilletBuilderRelativeAbscissa(handle, Int32(contour), vertex.handle)
    }

    /// Whether contour (1-based) is closed and tangent at closure.
    public func isClosedAndTangent(contour: Int) -> Bool {
        OCCTFilletBuilderClosedAndTangent(handle, Int32(contour))
    }

    /// Whether contour (1-based) is closed.
    public func isClosed(contour: Int) -> Bool {
        OCCTFilletBuilderClosed(handle, Int32(contour))
    }

    /// Number of surfaces after build.
    public var surfaceCount: Int { Int(OCCTFilletBuilderNbSurfaces(handle)) }

    /// Number of computed surfaces for contour (1-based).
    public func computedSurfaceCount(contour: Int) -> Int {
        Int(OCCTFilletBuilderNbComputedSurfaces(handle, Int32(contour)))
    }

    /// Error status for contour (1-based). Returns ChFiDS_ErrorStatus as Int.
    public func stripeStatus(contour: Int) -> Int {
        Int(OCCTFilletBuilderStripeStatus(handle, Int32(contour)))
    }

    /// Get the faulty contour index for the i-th fault (1-based).
    public func faultyContour(index: Int) -> Int {
        Int(OCCTFilletBuilderFaultyContour(handle, Int32(index)))
    }

    /// Get the faulty vertex for the i-th fault (1-based).
    public func faultyVertex(index: Int) -> Shape? {
        guard let ref = OCCTFilletBuilderFaultyVertex(handle, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - FilletBuilder completions (v0.126.0)

    /// Set fillet tolerances.
    public func setParams(tang: Double, tesp: Double, t2d: Double,
                          tApp3d: Double, tApp2d: Double, fleche: Double) {
        OCCTFilletBuilderSetParams(handle, tang, tesp, t2d, tApp3d, tApp2d, fleche)
    }

    /// Set the internal continuity of the generated fillet surfaces.
    ///
    /// `internalContinuity` is a ``ParametricContinuity`` raw value; OCCT's own domain here is
    /// "a continuity Ci (i=0, 1 or 2)", default C1. The bridge used to cast the integer straight
    /// to `GeomAbs_Shape`, which made `1` mean G1 and `2` mean C1 — one class below what this
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

    /// Reset radius info on a specific contour (1-based).
    public func resetContour(_ contourIndex: Int) {
        OCCTFilletBuilderResetContour(handle, Int32(contourIndex))
    }

    /// Simulate filleting on a contour (computes sections without building).
    public func simulate(contour: Int) {
        OCCTFilletBuilderSimulate(handle, Int32(contour))
    }

    /// Get the number of simulated surfaces for a contour (1-based).
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
        var first = 0.0, last = 0.0
        guard OCCTFilletBuilderGetBounds(handle, Int32(contour), edge.handle, &first, &last) else { return nil }
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
        guard let ref = OCCTFilletBuilderGetLaw(handle, Int32(contour), edge.handle) else { return nil }
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
        OCCTFilletBuilderSetLaw(handle, Int32(contour), edge.handle, law.handle)
    }

    /// The `Shape`-typed spelling of ``FilletBuilder/getBounds(contour:edge:)``.
    ///
    /// `BRepFilletAPI_MakeFillet::GetBounds` takes a `TopoDS_Edge`, so a `Shape` only ever reached
    /// it through a downcast, and every caller holding an `Edge` (the type `addEdge`, `removeEdge`,
    /// `setRadius` and `contour(for:)` all take) had to convert it and back again (#505).
    @available(*, deprecated, message: "Pass the Edge itself. Convert a Shape with Edge(_:) if that is what you hold.")
    public func getBounds(contour: Int, edge: Shape) -> (first: Double, last: Double)? {
        guard let edge = Edge(edge) else { return nil }
        return getBounds(contour: contour, edge: edge)
    }

    /// The `Shape`-typed spelling of ``FilletBuilder/getLaw(contour:edge:)``, deprecated for the same
    /// reason as the `Shape`-typed `getBounds` above it.
    @available(*, deprecated, message: "Pass the Edge itself. Convert a Shape with Edge(_:) if that is what you hold.")
    public func getLaw(contour: Int, edge: Shape) -> LawFunction? {
        guard let edge = Edge(edge) else { return nil }
        return getLaw(contour: contour, edge: edge)
    }

    /// Get shapes generated from an input shape by the fillet operation.
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
    /// The fillet must be built first.
    /// - Parameter shape: The input shape
    /// - Returns: true if the shape was deleted
    public func isDeleted(_ shape: Shape) -> Bool {
        OCCTFilletBuilderIsDeleted(handle, shape.handle)
    }
}
