import Foundation
import OCCTBridge
import simd

/// Edge analysis utilities using ShapeAnalysis_Edge.
public enum EdgeAnalysis {
    /// Check if an edge has a 3D curve.
    public static func hasCurve3d(_ edge: Shape) -> Bool {
        OCCTEdgeHasCurve3dSA(edge.handle)
    }

    /// Check if an edge is closed in 3D.
    public static func isClosed3d(_ edge: Shape) -> Bool {
        OCCTEdgeIsClosed3dSA(edge.handle)
    }

    /// Check if an edge has a PCurve on a face.
    public static func hasPCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeHasPCurveSA(edge.handle, face.handle)
    }

    /// Check if an edge is a seam edge on a face.
    public static func isSeam(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeIsSeamSA(edge.handle, face.handle)
    }

    /// Check same parameter consistency.
    ///
    /// Returns (ok, maxDeviation).
    public static func checkSameParameter(_ edge: Shape) -> (ok: Bool, maxDeviation: Double) {
        var maxdev = 0.0
        let ok = OCCTEdgeCheckSameParameter(edge.handle, &maxdev)
        return (ok, maxdev)
    }

    /// Check vertices with 3D curve positions.
    public static func checkVerticesWithCurve3d(_ edge: Shape, precision: Double = 1e-6) -> Bool {
        OCCTEdgeCheckVerticesWithCurve3d(edge.handle, precision)
    }

    /// Check vertices with PCurve positions on a face.
    public static func checkVerticesWithPCurve(
        _ edge: Shape, face: Shape,
        precision: Double = 1e-6
    ) -> Bool {
        OCCTEdgeCheckVerticesWithPCurve(edge.handle, face.handle, precision)
    }

    /// Check 3D curve vs PCurve consistency on a face.
    public static func checkCurve3dWithPCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeCheckCurve3dWithPCurve(edge.handle, face.handle)
    }

    /// Get the first vertex position of an edge.
    public static func firstVertex(_ edge: Shape) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTEdgeFirstVertexSA(edge.handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the last vertex position of an edge.
    public static func lastVertex(_ edge: Shape) -> SIMD3<Double> {
        var x = 0.0
        var y = 0.0
        var z = 0.0
        OCCTEdgeLastVertexSA(edge.handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Check vertex tolerances on a face edge.
    ///
    /// Returns (ok, toler1, toler2).
    public static func checkVertexTolerance(_ edge: Shape, face: Shape) -> (
        ok: Bool, toler1: Double, toler2: Double
    ) {
        var t1 = 0.0
        var t2 = 0.0
        let ok = OCCTEdgeCheckVertexTolerance(edge.handle, face.handle, &t1, &t2)
        return (ok, t1, t2)
    }

    /// Check if two edges overlap.
    ///
    /// - Parameters:
    ///   - edge1: The first edge.
    ///   - edge2: The second edge.
    ///   - tolerance: The overlap distance threshold. Defaults to `Precision::Confusion()`
    ///     (`1e-7`). Prior to #1438 this was fixed at `0.0` internally, which made the underlying
    ///     OCCT comparison always fail, so `checkOverlapping` always returned `false`.
    /// - Returns: (overlapping, tolerance) -- `tolerance` echoes back the threshold used.
    public static func checkOverlapping(_ edge1: Shape, _ edge2: Shape, tolerance: Double = 1e-7)
        -> (overlapping: Bool, tolerance: Double)
    {
        var tol = tolerance
        let ok = OCCTEdgeCheckOverlapping(edge1.handle, edge2.handle, tolerance, &tol)
        return (ok, tol)
    }

    /// Get UV bounds of an edge on a face.
    public static func boundUV(_ edge: Shape, face: Shape) -> (
        uFirst: Double, vFirst: Double, uLast: Double, vLast: Double
    )? {
        var uf = 0.0
        var vf = 0.0
        var ul = 0.0
        var vl = 0.0
        let ok = OCCTEdgeBoundUV(edge.handle, face.handle, &uf, &vf, &ul, &vl)
        if !ok { return nil }
        return (uf, vf, ul, vl)
    }

    /// Get end tangent in 2D for an edge on a face.
    public static func endTangent2d(
        _ edge: Shape, face: Shape,
        atEnd: Bool
    ) -> (point: SIMD2<Double>, tangent: SIMD2<Double>)? {
        var px = 0.0
        var py = 0.0
        var tx = 0.0
        var ty = 0.0
        let ok = OCCTEdgeGetEndTangent2d(edge.handle, face.handle, atEnd, &px, &py, &tx, &ty)
        if !ok { return nil }
        return (SIMD2(px, py), SIMD2(tx, ty))
    }

    /// Check whether `[first, last]` is a valid parameter range for the edge's pcurve on `face`.
    ///
    /// The check is against the pcurve's own underlying geometric domain (its full period, for a
    /// periodic pcurve), not against the edge's current stored trim range: a range can be valid
    /// here even when it extends beyond where the edge itself happens to be trimmed, as long as it
    /// stays within the pcurve's own domain (#1438).
    public static func checkPCurveRange(
        _ edge: Shape, face: Shape,
        first: Double, last: Double
    ) -> Bool {
        OCCTEdgeCheckPCurveRange(edge.handle, face.handle, first, last)
    }
}
