import Foundation
import OCCTBridge
import simd

/// Static utility functions for intersection computations.
public enum IntTools {

    /// Check if two vertex shapes are coincident (within tolerance).
    /// - Returns: 0 if coincident, non-zero otherwise
    public static func computeVV(_ vertex1: Shape, _ vertex2: Shape) -> Int {
        Int(OCCTIntToolsComputeVV(vertex1.handle, vertex2.handle))
    }

    /// Compute an intermediate parameter between two values.
    public static func intermediatePoint(first: Double, last: Double) -> Double {
        OCCTIntToolsIntermediatePoint(first, last)
    }

    /// Check if two directions are coincident (parallel or anti-parallel).
    public static func isDirsCoinside(
        dx1: Double, dy1: Double, dz1: Double,
        dx2: Double, dy2: Double, dz2: Double
    ) -> Bool {
        OCCTIntToolsIsDirsCoinside(dx1, dy1, dz1, dx2, dy2, dz2)
    }

    /// Check if two directions are coincident within a tolerance.
    public static func isDirsCoinside(
        dx1: Double, dy1: Double, dz1: Double,
        dx2: Double, dy2: Double, dz2: Double,
        tolerance: Double
    ) -> Bool {
        OCCTIntToolsIsDirsCoinisdeWithTol(dx1, dy1, dz1, dx2, dy2, dz2, tolerance)
    }

    /// Compute intersection range from tolerances and angle.
    public static func computeIntRange(tol1: Double, tol2: Double, angle: Double) -> Double {
        OCCTIntToolsComputeIntRange(tol1, tol2, angle)
    }
}
