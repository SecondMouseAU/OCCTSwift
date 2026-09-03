import Foundation
import OCCTBridge
import simd

/// Result of curve approximation as BSpline.
public struct ApproxCurveResult {
    public let curve: Curve3D?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}

/// Result of surface approximation as BSpline.
public struct ApproxSurfaceResult {
    public let surface: Surface?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}

/// Result of 2D curve approximation as BSpline.
public struct ApproxCurve2DResult {
    public let curve: Curve2D?
    public let maxError: Double
    public let isDone: Bool
    public let hasResult: Bool
}
