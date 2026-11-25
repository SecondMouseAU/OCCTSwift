import OCCTBridge
import OCCTPlatform

/// Builder for creating chamfers on edges of a shape, wrapping BRepFilletAPI_MakeChamfer.
///
/// ## Contour and edge indices (#3523)
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
/// let builder = ChamferBuilder(shape: box)!
/// print(builder.edgeCount(contour: 1))        // 0: no contour yet, and not a crash
/// builder.addEdge(box.edges()[0], distance: 1)
/// print(builder.edgeCount(contour: 1))        // 1
/// print(builder.edgeCount(contour: 0))        // 0, not contour 1
/// print(builder.edgeCount(contour: 2))        // 0
/// ```
public final class ChamferBuilder: @unchecked Sendable {
    private let handle: OCCTChamferBuilderRef
    private let input: Shape

    /// Create a chamfer builder on the given shape.
    public init?(shape: Shape) {
        guard let ref = OCCTChamferBuilderCreate(shape.handle) else { return nil }
        self.handle = ref
        self.input = shape
    }

    deinit { OCCTChamferBuilderRelease(handle) }

    /// Add an edge with symmetric chamfer distance.
    @discardableResult
    public func addEdge(_ edge: Edge, distance: Double) -> Bool {
        OCCTChamferBuilderAddEdge(handle, edge.handle, distance)
    }

    /// Add an edge with two distances (requires face for orientation).
    @discardableResult
    public func addEdge(_ edge: Edge, face: Face, distance1: Double, distance2: Double) -> Bool {
        OCCTChamferBuilderAddEdgeTwoDists(handle, edge.handle, face.handle, distance1, distance2)
    }

    /// Add an edge with distance and angle (requires face for orientation).
    @discardableResult
    public func addEdge(_ edge: Edge, face: Face, distance: Double, angle: Double) -> Bool {
        OCCTChamferBuilderAddEdgeDistAngle(handle, edge.handle, face.handle, distance, angle)
    }

    /// Build the chamfered result.
    ///
    /// Answers nil when the builder is not done, and also when it is done but the result is
    /// `BRepCheck`-invalid (#3200), has a different solid count than the input, or is the input
    /// unchanged (#3297, #3298).
    public func build() -> Shape? {
        guard let ref = OCCTChamferBuilderBuild(handle) else { return nil }
        let result = Shape(handle: ref)
        guard OCCTBlendResultIsSane(input.handle, result.handle) else { return nil }
        return result
    }

    /// Number of contours.
    public var contourCount: Int { Int(OCCTChamferBuilderNbContours(handle)) }

    /// Whether a contour uses distance-angle mode.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.isDistanceAngle(contour: 1))   // false: a symmetric chamfer
    /// print(builder.isDistanceAngle(contour: 2))   // false: no such contour
    /// ```
    public func isDistanceAngle(contour: Int) -> Bool {
        OCCTChamferBuilderIsDistAngle(handle, Int32(clamping: contour))
    }
}

extension ChamferBuilder {
    /// Number of edges in a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`. An index outside that
    ///   range, `0` and the negatives included, answers `0` (#3523).
    /// - Returns: The number of edges in the contour, or `0` for a contour that does not exist.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.edgeCount(contour: 1))   // 1
    /// print(builder.edgeCount(contour: 2))   // 0: past contourCount, not a crash
    /// ```
    public func edgeCount(contour: Int) -> Int {
        Int(OCCTChamferBuilderNbEdges(handle, Int32(clamping: contour)))
    }

    /// Get the symmetric distance for a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The distance, or `-1` for a contour that does not exist, the value OCCT documents
    ///   for an index outside its table (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 2)
    /// print(builder.getDistance(contour: 1))   // 2.0
    /// print(builder.getDistance(contour: 0))   // -1.0, not contour 1
    /// ```
    public func getDistance(contour: Int) -> Double {
        var dist: Double = -1.0
        OCCTChamferBuilderGetDist(handle, Int32(clamping: contour), &dist)
        return dist
    }

    /// Get the two distances for a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The two distances, or `(-1, -1)` for a contour that does not exist (#3523). A
    ///   contour that was not built with two distances answers `(-1, -1)` as well, because OCCT
    ///   refuses it with an exception.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.edges()[0]
    /// let face = edge.adjacentFaces(in: box)![0]
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(edge, face: face, distance1: 1, distance2: 2)
    /// print(builder.getDistances(contour: 1))   // (d1: 1.0, d2: 2.0)
    /// print(builder.getDistances(contour: 2))   // (d1: -1.0, d2: -1.0)
    /// ```
    public func getDistances(contour: Int) -> (d1: Double, d2: Double) {
        var d1: Double = -1.0
        var d2: Double = -1.0
        OCCTChamferBuilderGetDists(handle, Int32(clamping: contour), &d1, &d2)
        return (d1, d2)
    }

    /// Get distance and angle for a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The distance and angle, or `(-1, -1)` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.edges()[0]
    /// let face = edge.adjacentFaces(in: box)![0]
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(edge, face: face, distance: 1, angle: 0.5)
    /// print(builder.getDistAngle(contour: 1))   // (distance: 1.0, angle: 0.5)
    /// print(builder.getDistAngle(contour: 2))   // (distance: -1.0, angle: -1.0)
    /// ```
    public func getDistAngle(contour: Int) -> (distance: Double, angle: Double) {
        var dist: Double = -1.0
        var angle: Double = -1.0
        OCCTChamferBuilderGetDistAngle(handle, Int32(clamping: contour), &dist, &angle)
        return (dist, angle)
    }

    /// Set the symmetric distance on a contour.
    ///
    /// - Parameters:
    ///   - dist: The new distance.
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - face: A face the contour's edges lie on, which orients the chamfer.
    /// - Returns: `false`, and changes nothing, for a contour that does not exist. `0` and the
    ///   negatives used to rewrite contour 1, and an index past the end answered `true` for a write
    ///   that never happened (#3523). Also `false` when `face` is not common to any edge of the
    ///   contour.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.edges()[0]
    /// let face = edge.adjacentFaces(in: box)![0]
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(edge, distance: 1)
    /// print(builder.setDistance(3, contour: 1, face: face))   // true
    /// print(builder.setDistance(3, contour: 0, face: face))   // false: no contour 0
    /// ```
    @discardableResult
    public func setDistance(_ dist: Double, contour: Int, face: Face) -> Bool {
        OCCTChamferBuilderSetDist(handle, dist, Int32(clamping: contour), face.handle)
    }

    /// Set two distances on a contour.
    ///
    /// - Parameters:
    ///   - d1: The distance on `face`.
    ///   - d2: The distance on the other face.
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - face: A face the contour's edges lie on, which orients the chamfer.
    /// - Returns: `false`, and changes nothing, for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.edges()[0]
    /// let face = edge.adjacentFaces(in: box)![0]
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(edge, distance: 1)
    /// print(builder.setDistances(1, 2, contour: 1, face: face))    // true
    /// print(builder.setDistances(1, 2, contour: 5, face: face))    // false: no contour 5
    /// ```
    @discardableResult
    public func setDistances(_ d1: Double, _ d2: Double, contour: Int, face: Face) -> Bool {
        OCCTChamferBuilderSetDists(handle, d1, d2, Int32(clamping: contour), face.handle)
    }

    /// Set distance and angle on a contour.
    ///
    /// - Parameters:
    ///   - distance: The distance on `face`.
    ///   - angle: The angle, in radians.
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - face: A face the contour's edges lie on, which orients the chamfer.
    /// - Returns: `false`, and changes nothing, for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let edge = box.edges()[0]
    /// let face = edge.adjacentFaces(in: box)![0]
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(edge, distance: 1)
    /// print(builder.setDistAngle(distance: 1, angle: 0.5, contour: 1, face: face))   // true
    /// print(builder.setDistAngle(distance: 1, angle: 0.5, contour: -1, face: face))   // false
    /// ```
    @discardableResult
    public func setDistAngle(distance: Double, angle: Double, contour: Int, face: Face) -> Bool {
        OCCTChamferBuilderSetDistAngle(
            handle, distance, angle, Int32(clamping: contour), face.handle)
    }

    /// Length of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The length, or `-1` for a contour that does not exist, the value OCCT documents
    ///   for an index outside its table. `0` and the negatives used to answer contour 1 (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.length(contour: 1))   // 10.0
    /// print(builder.length(contour: 2))   // -1.0
    /// ```
    public func length(contour: Int) -> Double {
        OCCTChamferBuilderLength(handle, Int32(clamping: contour))
    }

    /// Remove the contour containing the given edge.
    @discardableResult
    public func removeEdge(_ edge: Edge) -> Bool {
        OCCTChamferBuilderRemoveEdge(handle, edge.handle)
    }

    /// Reset all contours, canceling effects of build.
    public func reset() {
        OCCTChamferBuilderReset(handle)
    }

    /// Whether a contour is closed.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.isClosed(contour: 1))   // false: one open edge
    /// print(builder.isClosed(contour: 0))   // false: no such contour
    /// ```
    public func isClosed(contour: Int) -> Bool {
        OCCTChamferBuilderClosed(handle, Int32(clamping: contour))
    }

    /// Whether a contour is closed and tangent at closure.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.isClosedAndTangent(contour: 1))   // false: one open edge
    /// print(builder.isClosedAndTangent(contour: 9))   // false: no such contour
    /// ```
    public func isClosedAndTangent(contour: Int) -> Bool {
        OCCTChamferBuilderClosedAndTangent(handle, Int32(clamping: contour))
    }

    /// Whether a contour is symmetric.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.isSymmetric(contour: 1))   // true
    /// print(builder.isSymmetric(contour: 2))   // false: no such contour
    /// ```
    public func isSymmetric(contour: Int) -> Bool {
        OCCTChamferBuilderIsSymmetric(handle, Int32(clamping: contour))
    }

    /// Whether a contour uses two distances.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The flag, or `false` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.isTwoDistances(contour: 1))   // false: a symmetric chamfer
    /// print(builder.isTwoDistances(contour: 0))   // false: no such contour
    /// ```
    public func isTwoDistances(contour: Int) -> Bool {
        OCCTChamferBuilderIsTwoDists(handle, Int32(clamping: contour))
    }

    /// Get edge `index` in a contour.
    ///
    /// - Parameters:
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - index: The 1-based position of the edge inside the contour, `1...edgeCount(contour:)`.
    /// - Returns: The edge, or `nil` when either index is outside its range (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.edge(contour: 1, index: 1) != nil)   // true
    /// print(builder.edge(contour: 1, index: 2) != nil)   // false: the contour holds one edge
    /// print(builder.edge(contour: 2, index: 1) != nil)   // false: no second contour
    /// ```
    public func edge(contour: Int, index: Int) -> Shape? {
        guard
            let ref = OCCTChamferBuilderEdge(
                handle, Int32(clamping: contour), Int32(clamping: index))
        else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get the first vertex of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The vertex, or `nil` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.firstVertex(contour: 1) != nil)   // true
    /// print(builder.firstVertex(contour: 0) != nil)   // false
    /// ```
    public func firstVertex(contour: Int) -> Shape? {
        guard let ref = OCCTChamferBuilderFirstVertex(handle, Int32(clamping: contour)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get the last vertex of a contour.
    ///
    /// - Parameter contour: The 1-based contour index, `1...contourCount`.
    /// - Returns: The vertex, or `nil` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// print(builder.lastVertex(contour: 1) != nil)   // true
    /// print(builder.lastVertex(contour: 2) != nil)   // false
    /// ```
    public func lastVertex(contour: Int) -> Shape? {
        guard let ref = OCCTChamferBuilderLastVertex(handle, Int32(clamping: contour)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get contour index for an edge (0 if not found).
    public func contour(for edge: Edge) -> Int {
        Int(OCCTChamferBuilderContour(handle, edge.handle))
    }

    /// Curvilinear abscissa of a vertex on a contour.
    ///
    /// - Parameters:
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - vertex: A vertex of the contour.
    /// - Returns: The abscissa, or `-1` for a contour that does not exist, the value OCCT
    ///   documents for an index outside its table (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// let end = builder.lastVertex(contour: 1)!
    /// print(builder.abscissa(contour: 1, vertex: end))   // 10.0
    /// print(builder.abscissa(contour: 0, vertex: end))   // -1.0
    /// ```
    public func abscissa(contour: Int, vertex: Shape) -> Double {
        OCCTChamferBuilderAbscissa(handle, Int32(clamping: contour), vertex.handle)
    }

    /// Relative abscissa (0 to 1) of a vertex on a contour.
    ///
    /// - Parameters:
    ///   - contour: The 1-based contour index, `1...contourCount`.
    ///   - vertex: A vertex of the contour.
    /// - Returns: The relative abscissa, or `-1` for a contour that does not exist (#3523).
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    /// let end = builder.lastVertex(contour: 1)!
    /// print(builder.relativeAbscissa(contour: 1, vertex: end))   // 1.0
    /// print(builder.relativeAbscissa(contour: 2, vertex: end))   // -1.0
    /// ```
    public func relativeAbscissa(contour: Int, vertex: Shape) -> Double {
        OCCTChamferBuilderRelativeAbscissa(handle, Int32(clamping: contour), vertex.handle)
    }
}

extension ChamferBuilder {

    /// Get shapes generated from an input shape by the chamfer operation.
    public func generated(from shape: Shape) -> [Shape] {
        var ptr: UnsafeMutablePointer<OCCTShapeRef?>?
        let count = OCCTChamferBuilderGenerated(handle, shape.handle, &ptr)
        guard count > 0, let shapes = ptr else { return [] }
        defer { free(shapes) }
        var result = [Shape]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = shapes[i] { result.append(Shape(handle: ref)) }
        }
        return result
    }

    /// Get shapes modified from an input shape by the chamfer operation.
    public func modified(from shape: Shape) -> [Shape] {
        var ptr: UnsafeMutablePointer<OCCTShapeRef?>?
        let count = OCCTChamferBuilderModified(handle, shape.handle, &ptr)
        guard count > 0, let shapes = ptr else { return [] }
        defer { free(shapes) }
        var result = [Shape]()
        result.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            if let ref = shapes[i] { result.append(Shape(handle: ref)) }
        }
        return result
    }

    /// Check if a shape was deleted by the chamfer operation.
    public func isDeleted(_ shape: Shape) -> Bool {
        OCCTChamferBuilderIsDeleted(handle, shape.handle)
    }

    /// Chamfer mode: classic, constant throat, or constant throat with penetration.
    public enum ChamferMode: Int32, Sendable {
        case classic = 0
        case constThroat = 1
        case constThroatWithPenetration = 2
    }

    /// Set the chamfer mode.
    public func setMode(_ mode: ChamferMode) {
        OCCTChamferBuilderSetMode(handle, mode.rawValue)
    }

    /// Simulate the chamfer on a contour (1-based index) without building.
    @discardableResult
    public func simulate(contour: Int) -> Bool {
        OCCTChamferBuilderSimulate(handle, Int32(clamping: contour))
    }

    /// Get the number of simulated surfaces for a contour (1-based).
    ///
    /// Answers `0` while the contour holds no surface data: it was never built or simulated,
    /// ``reset()`` has been called since, the simulation or build was declined, a simulation of
    /// another contour never reached it, or `contour` names no contour. OCCT reads this count from
    /// a sequence that only ``build()`` or ``simulate(contour:)`` creates for a contour, and
    /// reading it before either had run, or after a reset, used to fault the process uncatchably
    /// (#3522). A contour that ``build()`` has run on keeps the surface count that build left.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// let builder = ChamferBuilder(shape: box)!
    /// builder.addEdge(box.edges()[0], distance: 1)
    ///
    /// print(builder.simulatedSurfaceCount(contour: 1))   // 0: nothing has run on it yet
    /// builder.simulate(contour: 1)
    /// print(builder.simulatedSurfaceCount(contour: 1))   // 1: one chamfer face on a box edge
    /// builder.reset()
    /// print(builder.simulatedSurfaceCount(contour: 1))   // 0: reset discards the surface data
    /// ```
    public func simulatedSurfaceCount(contour: Int) -> Int {
        Int(OCCTChamferBuilderNbSurf(handle, Int32(clamping: contour)))
    }
}
