import Foundation
import OCCTBridge
import simd

/// A node in the medial axis graph.
///
/// Each node represents a point on the medial axis with an associated
/// inscribed circle radius (distance to the nearest boundary).
public struct MedialAxisNode: Sendable {
    /// 1-based index of this node in the graph.
    public let index: Int32

    /// 2D position of the node.
    public let position: SIMD2<Double>

    /// Distance to the nearest boundary (inscribed circle radius).
    public let distance: Double

    /// Whether this node has only one linked arc (an endpoint of the skeleton).
    public let isPending: Bool

    /// Whether this node lies on the shape boundary.
    public let isOnBoundary: Bool
}

/// An arc in the medial axis graph.
///
/// Each arc represents a bisector curve connecting two nodes and
/// separating two boundary elements.
public struct MedialAxisArc: Sendable {
    /// 1-based index of this arc in the graph.
    public let index: Int32

    /// Geometry index referencing the underlying bisector curve.
    public let geomIndex: Int32

    /// Index of the first endpoint node.
    public let firstNodeIndex: Int32

    /// Index of the second endpoint node.
    public let secondNodeIndex: Int32

    /// Index of the first boundary element adjacent to this arc.
    public let firstElementIndex: Int32

    /// Index of the second boundary element adjacent to this arc.
    public let secondElementIndex: Int32
}

/// Medial axis (Voronoi skeleton) of a planar face.
///
/// Computes the locus of centers of maximal inscribed circles within
/// a 2D profile. The result is a graph of arcs (bisector curves) and
/// nodes (arc endpoints), each annotated with the distance to the
/// nearest boundary.
///
/// Useful for:
/// - Thin wall detection (`minThickness`)
/// - Tool path generation (offset from skeleton)
/// - Shape decomposition and feature recognition
///
/// The input shape must contain at least one planar face. The medial
/// axis is computed from the first face found, using **all** of its wires:
/// the outer boundary and any inner (hole) wires alike, each contributing
/// its own contour. This is what makes thin-wall detection work, a hole's
/// boundary participates in the skeleton just as the outer wire does.
///
/// ```swift
/// let rect = Shape.makeFace(
///     wire: Shape.makePolygon([
///         SIMD3(0, 0, 0), SIMD3(10, 0, 0),
///         SIMD3(10, 4, 0), SIMD3(0, 4, 0)
///     ], closed: true)!
/// )!
/// if let ma = MedialAxis(of: rect) {
///     print("Arcs: \(ma.arcCount), Min thickness: \(ma.minThickness)")
/// }
/// ```
public final class MedialAxis: @unchecked Sendable {
    internal let handle: OCCTMedialAxisRef

    /// Compute the medial axis of a planar face.
    ///
    /// - Note: Only the **first** face found is used, but all of its wires are: the outer
    ///   boundary and any inner (hole) wires, each its own contour. A shape with several faces
    ///   returns the same result as that first face on its own; the rest are ignored, not merged.
    ///   Pass one face at a time to compute a medial axis per face.
    ///
    /// - Note: There is no tolerance. Neither `BRepMAT2d_Explorer::Perform` nor
    ///   `BRepMAT2d_BisectingLocus::Compute` accepts one; `Compute`'s own knobs are the line index,
    ///   the side, the join type and the open-result flag, all fixed here at OCCT's defaults.
    ///
    /// Fails, returning `nil`, if the computation fails or the shape has no faces.
    ///
    /// - Parameter shape: A shape containing at least one face.
    public init?(of shape: Shape) {
        guard let h = OCCTMedialAxisCompute(shape.handle) else {
            return nil
        }
        handle = h
    }

    deinit {
        OCCTMedialAxisRelease(handle)
    }

    // MARK: - Graph Counts

    /// Number of bisector arcs in the medial axis graph.
    public var arcCount: Int {
        Int(OCCTMedialAxisGetArcCount(handle))
    }

    /// Number of nodes (arc endpoints) in the medial axis graph.
    public var nodeCount: Int {
        Int(OCCTMedialAxisGetNodeCount(handle))
    }

    /// Number of boundary elements (input edges) used in the computation.
    public var basicElementCount: Int {
        Int(OCCTMedialAxisGetBasicEltCount(handle))
    }

    // MARK: - Node Access

    /// Get a node by its 1-based index.
    public func node(at index: Int) -> MedialAxisNode? {
        var raw = OCCTMedialAxisNode()
        guard OCCTMedialAxisGetNode(handle, Int32(index), &raw) else {
            return nil
        }
        return MedialAxisNode(
            index: raw.index,
            position: SIMD2(raw.x, raw.y),
            distance: raw.distance,
            isPending: raw.isPending,
            isOnBoundary: raw.isOnBoundary
        )
    }

    /// All nodes in the graph.
    public var nodes: [MedialAxisNode] {
        (1...max(nodeCount, 1)).compactMap { node(at: $0) }
    }

    // MARK: - Arc Access

    /// Get an arc by its 1-based index.
    public func arc(at index: Int) -> MedialAxisArc? {
        var raw = OCCTMedialAxisArc()
        guard OCCTMedialAxisGetArc(handle, Int32(index), &raw) else {
            return nil
        }
        return MedialAxisArc(
            index: raw.index,
            geomIndex: raw.geomIndex,
            firstNodeIndex: raw.firstNodeIndex,
            secondNodeIndex: raw.secondNodeIndex,
            firstElementIndex: raw.firstEltIndex,
            secondElementIndex: raw.secondEltIndex
        )
    }

    /// All arcs in the graph.
    public var arcs: [MedialAxisArc] {
        (1...max(arcCount, 1)).compactMap { arc(at: $0) }
    }

    // MARK: - Distance / Thickness

    /// Minimum inscribed circle radius across all nodes.
    ///
    /// This represents half of the minimum wall thickness of the shape.
    /// Returns -1 if the computation fails.
    public var minThickness: Double {
        OCCTMedialAxisMinThickness(handle)
    }

    /// Interpolated distance to boundary along an arc.
    ///
    /// - Parameters:
    ///   - arcIndex: 1-based arc index.
    ///   - t: Parameter in [0, 1] where 0 is the first node and 1 is the second.
    /// - Returns: Inscribed circle radius at the given parameter, or -1 on error.
    public func distanceToBoundary(arcIndex: Int, parameter t: Double) -> Double {
        OCCTMedialAxisDistanceOnArc(handle, Int32(arcIndex), t)
    }

    // MARK: - Drawing

    /// Sample points along a single bisector arc.
    ///
    /// - Parameters:
    ///   - index: 1-based arc index.
    ///   - maxPoints: Desired number of sample points (default 32), honoured within `2...`
    ///     ``Sampling/maximumSampleCount``; outside that range the result is empty (#558).
    ///
    ///     The name says capacity but the contract is a *request*: the bridge samples the arc's
    ///     parameter range at exactly `maxPoints` evenly-spaced values rather than letting a
    ///     deflection criterion pick the count, so it always returns exactly this many points
    ///     (and nothing at all below 2). That is why an unservable count is rejected here rather
    ///     than clamped the way the genuinely adaptive samplers clamp theirs, clamping this one
    ///     would hand back a different, coarser sampling than the caller asked for.
    /// - Returns: Array of 2D points along the arc, or empty on error.
    public func drawArc(at index: Int, maxPoints: Int = 32) -> [SIMD2<Double>] {
        guard let maxPoints = Sampling.requested(maxPoints) else { return [] }
        var xy = [Double](repeating: 0, count: maxPoints * 2)
        let count = OCCTMedialAxisDrawArc(handle, Int32(index), &xy, Int32(maxPoints))
        return (0..<Int(count)).map { i in
            SIMD2(xy[i * 2], xy[i * 2 + 1])
        }
    }

    /// Sample points along all bisector arcs.
    ///
    /// - Parameter maxPointsPerArc: Points requested per arc (default 32), at least 2, the same
    ///   fill-exactly request ``drawArc(at:maxPoints:)`` takes, not a capacity. The bound is on
    ///   the **total**: `arcCount * maxPointsPerArc` must not exceed
    ///   ``Sampling/maximumSampleCount``, else the result is empty (#558). Checking
    ///   `maxPointsPerArc` on its own is not redundant, since a negative count on a graph with no
    ///   arcs multiplies to a plausible total.
    /// - Returns: Array of polylines, one per arc.
    public func drawAll(maxPointsPerArc: Int = 32) -> [[SIMD2<Double>]] {
        guard maxPointsPerArc >= 2,
            let totalMax = Sampling.gridTotal(arcCount, maxPointsPerArc, atLeast: 0),
            totalMax > 0
        else { return [] }
        var xy = [Double](repeating: 0, count: totalMax * 2)
        var lineStarts = [Int32](repeating: 0, count: arcCount)
        var lineLengths = [Int32](repeating: 0, count: arcCount)
        let totalPoints = OCCTMedialAxisDrawAll(
            handle, &xy, Int32(totalMax),
            &lineStarts, &lineLengths, Int32(arcCount))
        guard totalPoints > 0 else { return [] }

        var result = [[SIMD2<Double>]]()
        for i in 0..<arcCount {
            guard i < lineStarts.count && i < lineLengths.count else { break }
            let start = Int(lineStarts[i])
            let length = Int(lineLengths[i])
            let polyline = (0..<length).map { j in
                SIMD2(xy[(start + j) * 2], xy[(start + j) * 2 + 1])
            }
            result.append(polyline)
        }
        return result
    }
}
