import Foundation
import OCCTBridge
import simd

/// Builder for creating chamfers on edges of a shape, wrapping BRepFilletAPI_MakeChamfer.
public final class ChamferBuilder: @unchecked Sendable {
    private let handle: OCCTChamferBuilderRef

    /// Create a chamfer builder on the given shape.
    public init?(shape: Shape) {
        guard let ref = OCCTChamferBuilderCreate(shape.handle) else { return nil }
        self.handle = ref
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
    public func build() -> Shape? {
        guard let ref = OCCTChamferBuilderBuild(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Number of contours.
    public var contourCount: Int { Int(OCCTChamferBuilderNbContours(handle)) }

    /// Whether a contour uses distance-angle mode (1-based index).
    public func isDistanceAngle(contour: Int) -> Bool {
        OCCTChamferBuilderIsDistAngle(handle, Int32(contour))
    }
}

extension ChamferBuilder {
    /// Number of edges in contour (1-based index).
    public func edgeCount(contour: Int) -> Int {
        Int(OCCTChamferBuilderNbEdges(handle, Int32(contour)))
    }

    /// Get the symmetric distance for a contour (1-based).
    public func getDistance(contour: Int) -> Double {
        var dist: Double = -1.0
        OCCTChamferBuilderGetDist(handle, Int32(contour), &dist)
        return dist
    }

    /// Get the two distances for a contour (1-based).
    public func getDistances(contour: Int) -> (d1: Double, d2: Double) {
        var d1: Double = -1.0
        var d2: Double = -1.0
        OCCTChamferBuilderGetDists(handle, Int32(contour), &d1, &d2)
        return (d1, d2)
    }

    /// Get distance and angle for a contour (1-based).
    public func getDistAngle(contour: Int) -> (distance: Double, angle: Double) {
        var dist: Double = -1.0
        var angle: Double = -1.0
        OCCTChamferBuilderGetDistAngle(handle, Int32(contour), &dist, &angle)
        return (dist, angle)
    }

    /// Set symmetric distance on a contour (1-based, requires face for orientation).
    @discardableResult
    public func setDistance(_ dist: Double, contour: Int, face: Face) -> Bool {
        OCCTChamferBuilderSetDist(handle, dist, Int32(contour), face.handle)
    }

    /// Set two distances on a contour (1-based, requires face for orientation).
    @discardableResult
    public func setDistances(_ d1: Double, _ d2: Double, contour: Int, face: Face) -> Bool {
        OCCTChamferBuilderSetDists(handle, d1, d2, Int32(contour), face.handle)
    }

    /// Set distance and angle on a contour (1-based, requires face for orientation).
    @discardableResult
    public func setDistAngle(distance: Double, angle: Double, contour: Int, face: Face) -> Bool {
        OCCTChamferBuilderSetDistAngle(handle, distance, angle, Int32(contour), face.handle)
    }

    /// Length of contour (1-based).
    public func length(contour: Int) -> Double {
        OCCTChamferBuilderLength(handle, Int32(contour))
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

    /// Whether contour (1-based) is closed.
    public func isClosed(contour: Int) -> Bool {
        OCCTChamferBuilderClosed(handle, Int32(contour))
    }

    /// Whether contour (1-based) is closed and tangent at closure.
    public func isClosedAndTangent(contour: Int) -> Bool {
        OCCTChamferBuilderClosedAndTangent(handle, Int32(contour))
    }

    /// Whether contour (1-based) is symmetric.
    public func isSymmetric(contour: Int) -> Bool {
        OCCTChamferBuilderIsSymmetric(handle, Int32(contour))
    }

    /// Whether contour (1-based) uses two distances.
    public func isTwoDistances(contour: Int) -> Bool {
        OCCTChamferBuilderIsTwoDists(handle, Int32(contour))
    }

    /// Get edge J in contour I (both 1-based).
    public func edge(contour: Int, index: Int) -> Shape? {
        guard let ref = OCCTChamferBuilderEdge(handle, Int32(contour), Int32(index)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get first vertex of contour (1-based).
    public func firstVertex(contour: Int) -> Shape? {
        guard let ref = OCCTChamferBuilderFirstVertex(handle, Int32(contour)) else { return nil }
        return Shape(handle: ref)
    }

    /// Get last vertex of contour (1-based).
    public func lastVertex(contour: Int) -> Shape? {
        guard let ref = OCCTChamferBuilderLastVertex(handle, Int32(contour)) else { return nil }
        return Shape(handle: ref)
    }

    /// Get contour index for an edge (0 if not found).
    public func contour(for edge: Edge) -> Int {
        Int(OCCTChamferBuilderContour(handle, edge.handle))
    }

    /// Curvilinear abscissa of vertex on contour (1-based).
    public func abscissa(contour: Int, vertex: Shape) -> Double {
        OCCTChamferBuilderAbscissa(handle, Int32(contour), vertex.handle)
    }

    /// Relative abscissa (0..1) of vertex on contour (1-based).
    public func relativeAbscissa(contour: Int, vertex: Shape) -> Double {
        OCCTChamferBuilderRelativeAbscissa(handle, Int32(contour), vertex.handle)
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
        OCCTChamferBuilderSimulate(handle, Int32(contour))
    }

    /// Get the number of simulated surfaces for a contour (1-based).
    ///
    /// Call after simulate.
    public func simulatedSurfaceCount(contour: Int) -> Int {
        Int(OCCTChamferBuilderNbSurf(handle, Int32(contour)))
    }
}
