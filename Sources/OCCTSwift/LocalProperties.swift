import Foundation
import OCCTBridge
import simd

/// Curve local properties at a parameter point
public struct CurveLocalProperties: Sendable {
    public let point: SIMD3<Double>
    public let tangent: SIMD3<Double>?
    public let normal: SIMD3<Double>?
    public let centerOfCurvature: SIMD3<Double>?
    public let curvature: Double
}

/// Surface local properties at a (U,V) parameter point
public struct SurfaceLocalProperties: Sendable {
    public let point: SIMD3<Double>
    public let normal: SIMD3<Double>?
    public let tangentU: SIMD3<Double>?
    public let tangentV: SIMD3<Double>?
    public let maxCurvature: Double
    public let minCurvature: Double
    public let meanCurvature: Double
    public let gaussianCurvature: Double
    /// Whether the four curvature values above mean anything.
    ///
    /// They are all `0` where curvature is undefined — a cone's apex, a sphere's pole, any point
    /// with no defined normal — which is indistinguishable from a genuinely flat point without
    /// this flag. The bridge has always computed it; it was simply not carried through to Swift
    /// until #494, which is why the per-scalar siblings (`Face.gaussianCurvature(atU:v:)` and
    /// friends, all returning optionals) were the only way to tell the two apart.
    public let curvatureDefined: Bool
    public let isUmbilic: Bool
}

/// Trihedron frame (tangent, normal, binormal) at a curve parameter
public struct TrihedronFrame: Sendable {
    public let tangent: SIMD3<Double>
    public let normal: SIMD3<Double>
    public let binormal: SIMD3<Double>
}
