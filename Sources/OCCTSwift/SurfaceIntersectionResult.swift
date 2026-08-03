import Foundation
import simd
import OCCTBridge

/// Surface-surface intersection result
public class SurfaceIntersectionResult {
    let ref: OCCTGeomIntSSRef

    init(_ ref: OCCTGeomIntSSRef) {
        self.ref = ref
    }

    deinit {
        OCCTGeomIntSSRelease(ref)
    }

    /// Number of intersection curves
    public var curveCount: Int {
        Int(OCCTGeomIntSSLineCount(ref))
    }

    /// Get an intersection curve as an edge shape (1-based index)
    public func curve(_ index: Int) -> Shape? {
        guard let h = OCCTGeomIntSSLine(ref, Int32(index)) else { return nil }
        return Shape(handle: h)
    }

    /// Number of isolated intersection points
    public var pointCount: Int {
        Int(OCCTGeomIntSSPointCount(ref))
    }

    /// Get an intersection point (1-based index)
    public func point(_ index: Int) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTGeomIntSSPoint(ref, Int32(index), &x, &y, &z)
        return SIMD3(x, y, z)
    }
}
