import Foundation
import OCCTBridge
import simd

/// A general 2D transformation (supports non-uniform scaling/affinity), wrapping gp_GTrsf2d.
public struct GeneralTransform2D: Sendable {
    /// 2x2 matrix (row-major: m11, m12, m21, m22)
    public let matrix: [Double]
    /// Translation vector
    public let translation: SIMD2<Double>

    /// Create an affinity transformation about a 2D axis with given ratio.
    public static func affinity(
        axisOrigin: SIMD2<Double>, axisDirection: SIMD2<Double>, ratio: Double
    ) -> GeneralTransform2D {
        var mat = [Double](repeating: 0, count: 4)
        var tx = 0.0
        var ty = 0.0
        OCCTGTrsf2dAffinity(
            axisOrigin.x, axisOrigin.y, axisDirection.x, axisDirection.y, ratio, &mat, &tx, &ty)
        return GeneralTransform2D(matrix: mat, translation: SIMD2(tx, ty))
    }

    /// Multiply this transform by another.
    public func multiplied(by other: GeneralTransform2D) -> GeneralTransform2D {
        var matR = [Double](repeating: 0, count: 4)
        var txR = 0.0
        var tyR = 0.0
        OCCTGTrsf2dMultiply(
            matrix, translation.x, translation.y,
            other.matrix, other.translation.x, other.translation.y,
            &matR, &txR, &tyR)
        return GeneralTransform2D(matrix: matR, translation: SIMD2(txR, tyR))
    }

    /// Invert this transform.
    public func inverted() -> GeneralTransform2D? {
        var matR = [Double](repeating: 0, count: 4)
        var txR = 0.0
        var tyR = 0.0
        guard OCCTGTrsf2dInvert(matrix, translation.x, translation.y, &matR, &txR, &tyR) else {
            return nil
        }
        return GeneralTransform2D(matrix: matR, translation: SIMD2(txR, tyR))
    }

    /// Transform a 2D point.
    public func transformPoint(_ point: SIMD2<Double>) -> SIMD2<Double> {
        var rx = 0.0
        var ry = 0.0
        OCCTGTrsf2dTransformPoint(matrix, translation.x, translation.y, point.x, point.y, &rx, &ry)
        return SIMD2(rx, ry)
    }
}
