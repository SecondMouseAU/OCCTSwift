import Foundation
import simd
import OCCTBridge

/// Curve defined by an edge lying on another edge (from blend operations).
public final class BiTgteCurveOnEdge: @unchecked Sendable {
    internal let handle: OCCTBiTgteCurveOnEdgeRef

    /// Create a curve-on-edge from two edges.
    public init?(edgeOnFace: Shape, edge: Shape) {
        guard let h = OCCTBiTgteCurveOnEdgeCreate(edgeOnFace.handle, edge.handle) else { return nil }
        self.handle = h
    }

    deinit { OCCTBiTgteCurveOnEdgeRelease(handle) }

    /// Parameter domain of the curve.
    public var domain: ClosedRange<Double> {
        var first = 0.0, last = 0.0
        OCCTBiTgteCurveOnEdgeDomain(handle, &first, &last)
        return first...last
    }

    /// Evaluate point at parameter u.
    public func point(at u: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTBiTgteCurveOnEdgeValue(handle, u, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}
