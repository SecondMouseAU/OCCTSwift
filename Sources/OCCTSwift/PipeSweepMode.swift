import Foundation
import OCCTBridge
import simd

/// Sweep mode for advanced pipe creation.
public enum PipeSweepMode: Sendable {
    /// Standard Frenet trihedron - profile orientation follows spine curvature
    case frenet
    /// Corrected Frenet - avoids twisting at inflection points
    case correctedFrenet
    /// Fixed binormal direction - profile maintains constant orientation
    case fixed(binormal: SIMD3<Double>)
    /// Auxiliary spine - twist controlled by secondary curve
    case auxiliary(spine: Wire)
}

/// Transition mode for pipe shell at spine discontinuities (corners).
public enum PipeTransitionMode: Int32, Sendable {
    /// Transformed — smooth transition (default)
    case transformed = 0
    /// Right corner — sharp right-angle transitions
    case rightCorner = 1
    /// Round corner — filleted transitions
    case roundCorner = 2
}
