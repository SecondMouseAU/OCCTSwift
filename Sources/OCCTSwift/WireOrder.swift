import Foundation
import OCCTBridge
import simd

/// Result of wire edge ordering analysis using ShapeAnalysis_WireOrder.
///
/// Analyzes a set of edges (defined by their endpoints) and determines
/// the order in which they should be connected to form continuous chains.
///
/// ```swift
/// let edges = [
///     (start: SIMD3(0,0,0), end: SIMD3(10,0,0)),
///     (start: SIMD3(10,10,0), end: SIMD3(0,10,0)),
///     (start: SIMD3(0,10,0), end: SIMD3(0,0,0)),
///     (start: SIMD3(10,0,0), end: SIMD3(10,10,0)),
/// ]
/// let result = WireOrder.analyze(edges: edges)
/// // result.orderedIndices gives the correct ordering
/// ```
public struct WireOrder: Sendable {
    /// Status of the wire ordering analysis.
    public enum Status: Sendable {
        /// Edges form a closed loop
        case closed
        /// Edges form an open chain
        case open
        /// Edges have gaps (not fully connected)
        case gaps
        /// Analysis failed
        case failed
    }

    /// An entry in the ordered edge sequence.
    public struct OrderedEdge: Sendable {
        /// Original edge index (0-based).
        public let originalIndex: Int
        /// Whether the edge should be reversed in the chain.
        public let isReversed: Bool
    }

    /// Status of the ordering analysis.
    public let status: Status
    /// Ordered sequence of edges.
    public let orderedEdges: [OrderedEdge]

    /// Analyze the ordering of edges defined by their start/end 3D points.
    ///
    /// - Parameters:
    ///   - edges: Array of (start, end) point pairs defining each edge
    ///   - tolerance: Connection tolerance (default 1e-3)
    /// - Returns: Wire ordering result, or nil if analysis failed
    public static func analyze(
        edges: [(start: SIMD3<Double>, end: SIMD3<Double>)],
        tolerance: Double = 1e-3
    ) -> WireOrder? {
        guard !edges.isEmpty else { return nil }

        let nbEdges = Int32(edges.count)
        var starts = [Double](repeating: 0, count: edges.count * 3)
        var ends = [Double](repeating: 0, count: edges.count * 3)

        for (i, edge) in edges.enumerated() {
            starts[i * 3] = edge.start.x
            starts[i * 3 + 1] = edge.start.y
            starts[i * 3 + 2] = edge.start.z
            ends[i * 3] = edge.end.x
            ends[i * 3 + 1] = edge.end.y
            ends[i * 3 + 2] = edge.end.z
        }

        var outOrder = [OCCTWireOrderEntry](
            repeating: OCCTWireOrderEntry(originalIndex: 0),
            count: edges.count)

        let result = OCCTWireOrderAnalyze(&starts, &ends, nbEdges, tolerance, &outOrder)

        return decode(result, outOrder: outOrder)
    }

    /// Analyze the ordering of edges in an existing wire.
    ///
    /// - Parameters:
    ///   - wire: Wire to analyze
    ///   - tolerance: Connection tolerance (default 1e-3)
    /// - Returns: Wire ordering result, or nil if analysis failed
    public static func analyze(wire: Wire, tolerance: Double = 1e-3) -> WireOrder? {
        let maxEntries: Int32 = 1000
        var outOrder = [OCCTWireOrderEntry](
            repeating: OCCTWireOrderEntry(originalIndex: 0),
            count: Int(maxEntries))

        let result = OCCTWireOrderAnalyzeWire(wire.handle, tolerance, &outOrder, maxEntries)

        return decode(result, outOrder: outOrder)
    }

    /// Decode a bridge `OCCTWireOrderResult` and its populated `outOrder` entries into a
    /// `WireOrder`.
    ///
    /// Shared by both `analyze(edges:)` and `analyze(wire:)`, which differ only in
    /// how they build the C-side inputs (caller-supplied points vs. a wire's own edges), not in
    /// how the result is interpreted.
    private static func decode(_ result: OCCTWireOrderResult, outOrder: [OCCTWireOrderEntry])
        -> WireOrder?
    {
        let status: Status
        switch result.status {
        case 0: status = .closed
        case 1: status = .open
        case 2: status = .gaps
        default: status = .failed
        }

        if result.status < 0 { return nil }

        var orderedEdges = [OrderedEdge]()
        orderedEdges.reserveCapacity(Int(result.nbEdges))
        for i in 0..<Int(result.nbEdges) {
            let idx = outOrder[i].originalIndex
            orderedEdges.append(
                OrderedEdge(
                    originalIndex: abs(Int(idx)) - 1,  // Convert from 1-based to 0-based
                    isReversed: idx < 0
                ))
        }

        return WireOrder(status: status, orderedEdges: orderedEdges)
    }
}
