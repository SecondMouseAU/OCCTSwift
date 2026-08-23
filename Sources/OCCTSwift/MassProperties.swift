import Foundation
import OCCTBridge
import simd

/// Linear mass properties computed from mesh polygon points.
///
/// `centerOfMass` is nil when `mass` is 0, which covers a polygon of fewer than two points and.
/// one whose points are all coincident (#609).
public struct MeshCinertResult {
    public let mass: Double
    public let centerOfMass: SIMD3<Double>?
}

/// Compute linear mass properties from polygon points.
public func meshCinertCompute(points: [(Double, Double, Double)]) -> MeshCinertResult {
    var coords: [Double] = []
    for p in points {
        coords.append(p.0)
        coords.append(p.1)
        coords.append(p.2)
    }
    let r = OCCTMeshCinertCompute(coords, Int32(points.count))
    return MeshCinertResult(
        mass: r.mass,
        centerOfMass: r.mass == 0 ? nil : SIMD3(r.centerX, r.centerY, r.centerZ))
}

/// Mesh property type.
public enum MeshPropsType {
    case volume
    case surface
}

/// Mesh surface/volume properties result.
///
/// `centerOfMass` is nil when `mass` is 0, which covers both an untriangulated face and a.
/// volume contribution that cancels.
///
/// See `FaceVolumeInertia` for why the mass itself stays.
/// non-optional (#609).
public struct MeshPropsResult {
    public let mass: Double
    public let centerOfMass: SIMD3<Double>?
}

/// Curve inertia properties (length and center of mass).
///
/// `centerOfMass` is nil when `length` is 0, which is what OCCT reports when there is nothing.
/// to integrate.
///
/// The (0,0,0) it used to expose in that case was the framework's location seed, not.
/// a point on the curve (#609).
public struct CurveInertia {
    public let length: Double
    public let centerOfMass: SIMD3<Double>?
}

/// Face surface inertia properties (area and center of mass).
///
/// `centerOfMass` is nil when `area` is 0.
///
/// See `CurveInertia` for why that is not a zero.
public struct FaceSurfaceInertia {
    public let area: Double
    public let centerOfMass: SIMD3<Double>?
    public let epsilon: Double
}

/// Face volume inertia contribution.
///
/// `volume` stays non-optional because a zero contribution is a real, useful answer: this is the
/// divergence-theorem decomposition, so a face whose plane contains the reference point contributes.
/// exactly nothing and a caller summing over a shell needs that 0. `centerOfMass` is nil there,.
/// because a zero contribution has no centroid and the (0,0,0) reported before was the framework's.
/// location seed (#609).
public struct FaceVolumeInertia {
    public let volume: Double
    public let centerOfMass: SIMD3<Double>?
}
