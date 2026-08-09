import Foundation
import simd
import OCCTBridge

extension Shape {

    /// Project a wire or edge onto this shape along surface normals.
    ///
    /// - Parameters:
    ///   - wireOrEdge: The wire or edge to project
    ///   - tolerance3D: 3D tolerance (default: 1e-4)
    ///   - tolerance2D: 2D tolerance (default: 1e-5)
    ///   - maxDegree: Maximum BSpline degree (default: 14)
    ///   - maxSegments: Maximum BSpline segments (default: 16)
    /// - Returns: The projected shape, or nil on failure
    public func normalProjection(of wireOrEdge: Shape,
                                  tolerance3D: Double = 1e-4,
                                  tolerance2D: Double = 1e-5,
                                  maxDegree: Int = 14,
                                  maxSegments: Int = 16) -> Shape? {
        guard let h = OCCTShapeNormalProjection(wireOrEdge.handle, handle,
                                                 tolerance3D, tolerance2D,
                                                 Int32(maxDegree), Int32(maxSegments))
        else { return nil }
        return Shape(handle: h)
    }
    /// Project a wire/edge shape onto another shape along a direction (cylindrical projection).
    ///
    /// - Parameters:
    ///   - wire: Wire or edge shape to project
    ///   - target: Target shape to project onto
    ///   - direction: Projection direction
    /// - Returns: Compound of projected wires, or nil on failure
    public static func projectWire(_ wire: Shape, onto target: Shape,
                                   direction: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeProjectWire(wire.handle, target.handle,
                                            direction.x, direction.y, direction.z) else { return nil }
        return Shape(handle: h)
    }

    /// Project a Wire onto another shape along a direction (cylindrical projection).
    ///
    /// Convenience overload accepting a `Wire` directly.
    public static func projectWire(_ wire: Wire, onto target: Shape,
                                   direction: SIMD3<Double>) -> Shape? {
        guard let wireShape = Shape.fromWire(wire) else { return nil }
        return projectWire(wireShape, onto: target, direction: direction)
    }
    /// Project a wire/edge shape onto another shape from a point (conical projection).
    ///
    /// Unlike cylindrical projection (parallel rays), conical projection fans out
    /// from a point source, like a spotlight or perspective camera.
    ///
    /// - Parameters:
    ///   - wire: Wire or edge shape to project
    ///   - target: Target shape to project onto
    ///   - eye: Point source of projection rays
    /// - Returns: Compound of projected wires, or nil on failure
    public static func projectWireConical(_ wire: Shape, onto target: Shape,
                                          eye: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeProjectWireConical(wire.handle, target.handle,
                                                   eye.x, eye.y, eye.z) else { return nil }
        return Shape(handle: h)
    }

    /// Project a Wire onto another shape from a point (conical projection).
    ///
    /// Convenience overload accepting a `Wire` directly.
    public static func projectWireConical(_ wire: Wire, onto target: Shape,
                                          eye: SIMD3<Double>) -> Shape? {
        guard let wireShape = Shape.fromWire(wire) else { return nil }
        return projectWireConical(wireShape, onto: target, eye: eye)
    }

    /// Compute reflect (silhouette) lines on a shape.
    /// - Parameters:
    ///   - normal: View plane normal direction
    ///   - viewPoint: View target point (eye position)
    ///   - up: Up direction
    /// - Returns: Compound of reflect line edges in 3D, or nil on failure
    public func reflectLines(normal: SIMD3<Double>, viewPoint: SIMD3<Double>,
                             up: SIMD3<Double>) -> Shape? {
        guard let h = OCCTHLRReflectLines(handle,
            normal.x, normal.y, normal.z,
            viewPoint.x, viewPoint.y, viewPoint.z,
            up.x, up.y, up.z) else { return nil }
        return Shape(handle: h)
    }

    /// Compute reflect lines and get specific edge types.
    public func reflectLinesFiltered(normal: SIMD3<Double>, viewPoint: SIMD3<Double>,
                                      up: SIMD3<Double>, edgeType: HLREdgeType,
                                      visible: Bool, in3d: Bool) -> Shape? {
        guard let h = OCCTHLRReflectLinesFiltered(handle,
            normal.x, normal.y, normal.z,
            viewPoint.x, viewPoint.y, viewPoint.z,
            up.x, up.y, up.z,
            edgeType.rawValue, visible, in3d) else { return nil }
        return Shape(handle: h)
    }
}
