import Foundation
import simd
import OCCTBridge

/// A 2x2 matrix for 2D operations, wrapping gp_Mat2d.
public enum Matrix2D {

    /// Identity matrix.
    public static func identity() -> [Double] {
        var mat = [Double](repeating: 0, count: 4)
        OCCTMat2dIdentity(&mat)
        return mat
    }

    /// Rotation matrix for given angle.
    public static func rotation(angle: Double) -> [Double] {
        var mat = [Double](repeating: 0, count: 4)
        OCCTMat2dRotation(angle, &mat)
        return mat
    }

    /// Uniform scale matrix.
    public static func scale(_ s: Double) -> [Double] {
        var mat = [Double](repeating: 0, count: 4)
        OCCTMat2dScale(s, &mat)
        return mat
    }

    /// Determinant of a 2x2 matrix.
    public static func determinant(_ mat: [Double]) -> Double {
        OCCTMat2dDeterminant(mat)
    }

    /// Invert a 2x2 matrix.
    public static func invert(_ mat: [Double]) -> [Double]? {
        var result = [Double](repeating: 0, count: 4)
        guard OCCTMat2dInvert(mat, &result) else { return nil }
        return result
    }

    /// Multiply two 2x2 matrices.
    public static func multiply(_ a: [Double], _ b: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: 4)
        OCCTMat2dMultiply(a, b, &result)
        return result
    }

    /// Transpose a 2x2 matrix.
    public static func transpose(_ mat: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: 4)
        OCCTMat2dTranspose(mat, &result)
        return result
    }
}
