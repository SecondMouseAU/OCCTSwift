import Foundation
import OCCTBridge
import simd

extension GeometryProperties {
    /// Cylinder lateral surface area.
    public static func cylinderSurfaceArea(radius: Double, height: Double) -> Double {
        OCCTGPropCylinderSurface(radius, height)
    }

    /// Cylinder volume.
    public static func cylinderVolume(radius: Double, height: Double) -> Double {
        OCCTGPropCylinderVolume(radius, height)
    }

    /// Cone lateral surface area.
    public static func coneSurfaceArea(semiAngle: Double, refRadius: Double, height: Double)
        -> Double
    {
        OCCTGPropConeSurface(semiAngle, refRadius, height)
    }

    /// Cone volume.
    public static func coneVolume(semiAngle: Double, refRadius: Double, height: Double) -> Double {
        OCCTGPropConeVolume(semiAngle, refRadius, height)
    }
}

/// Analytical geometry property computation.
///
/// Two different zero-mass cases live here, and #609 treats them differently:
///
/// - **A valid element measured over an empty range** keeps its answer. `GProp_CelGProps` computes
///   the centroid analytically rather than accumulating into a `GProp_GProps` framework, so an arc
///   with `u1 == u2` has a mass of 0 and a *correct* centre, measured at (105,200,300) for a line
///   through (100,200,300) sampled at parameter 5. Refusing would discard a right answer.
/// - **An input OCCT rejects** has no answer. Both curve members build a `gp_Dir` from caller data,
///   and that throws on a zero-length vector: coincident endpoints for a segment, a zero normal for
///   an arc. Those return nil rather than a length of 0 with a centre of (0,0,0).
///
/// The point-set members are the second kind throughout, since an empty set has no centroid.
public enum GeometryProperties {

    /// Line segment properties: returns (length, centerOfMass), or nil when OCCT rejects the input.
    ///
    /// Nil means two coincident endpoints, which give no direction to build a line from. That used
    /// to come back as a length of 0 with a centre of (0,0,0), a plausible answer for a segment
    /// that has none (#609).
    ///
    /// ```swift
    /// let p = SIMD3(3.0, 4.0, 5.0)
    /// GeometryProperties.lineSegment(from: .zero, to: p)?.length   // 7.07
    /// GeometryProperties.lineSegment(from: p, to: p)               // nil
    /// ```
    public static func lineSegment(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> (
        length: Double, center: SIMD3<Double>
    )? {
        var length = 0.0
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        guard OCCTGPropLineSegment(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, &length, &cx, &cy, &cz)
        else { return nil }
        return (length, SIMD3(cx, cy, cz))
    }

    /// Circular arc properties: returns (arcLength, centerOfMass), or nil when OCCT rejects the
    /// input, which for an arc means a zero normal vector.
    ///
    /// A valid arc with `u1 == u2` is not a rejection: it answers with an arc length of 0 and the
    /// correct centre, because `GProp_CelGProps` computes the centroid analytically rather than by
    /// accumulating mass.
    ///
    /// ```swift
    /// GeometryProperties.circularArc(center: .zero, normal: SIMD3(0,0,1),
    ///                                radius: 5, u1: 0, u2: .pi)?.arcLength   // 15.7
    /// GeometryProperties.circularArc(center: .zero, normal: .zero,
    ///                                radius: 5, u1: 0, u2: .pi)              // nil
    /// ```
    public static func circularArc(
        center: SIMD3<Double>, normal: SIMD3<Double>,
        radius: Double, u1: Double, u2: Double
    ) -> (arcLength: Double, center: SIMD3<Double>)? {
        var length = 0.0
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        guard
            OCCTGPropCircularArc(
                center.x, center.y, center.z,
                normal.x, normal.y, normal.z,
                radius, u1, u2, &length, &cx, &cy, &cz)
        else { return nil }
        return (length, SIMD3(cx, cy, cz))
    }

    /// Point set centroid.
    ///
    /// Returns (pointCount, centroid), with a nil centroid for an empty set.
    ///
    /// An empty set has no centroid. This used to report (0,0,0), which no caller could tell apart
    /// from the centroid of a set centred on the origin (#609).
    ///
    /// ```swift
    /// GeometryProperties.pointSetCentroid([SIMD3(0,0,0), SIMD3(2,0,0)]).centroid  // (1,0,0)
    /// GeometryProperties.pointSetCentroid([]).centroid                            // nil
    /// ```
    public static func pointSetCentroid(_ points: [SIMD3<Double>]) -> (
        count: Double, centroid: SIMD3<Double>?
    ) {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        let mass = OCCTGPropPointSetCentroid(flat, Int32(points.count), &cx, &cy, &cz)
        return (mass, mass == 0 ? nil : SIMD3(cx, cy, cz))
    }

    /// Sphere surface area (analytical).
    public static func sphereSurfaceArea(radius: Double) -> Double {
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        return OCCTGPropSphereSurface(radius, &cx, &cy, &cz)
    }

    /// Sphere volume (analytical).
    public static func sphereVolume(radius: Double) -> Double {
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        return OCCTGPropSphereVolume(radius, &cx, &cy, &cz)
    }
}

extension GeometryProperties {
    /// Full torus surface area.
    public static func torusSurfaceArea(majorRadius: Double, minorRadius: Double) -> Double {
        OCCTGPropTorusSurface(majorRadius, minorRadius)
    }

    /// Full torus volume.
    public static func torusVolume(majorRadius: Double, minorRadius: Double) -> Double {
        OCCTGPropTorusVolume(majorRadius, minorRadius)
    }
}

extension GeometryProperties {
    /// Compute weighted centroid of a point set.
    ///
    /// Returns (totalMass, centroid), with a nil centroid when there is none to report.
    ///
    /// **`weights` must have exactly as many elements as `points`.** A mismatch is rejected
    /// (mass 0, centroid nil) rather than read past the shorter array's end (#1583).
    ///
    /// **Every weight must be strictly positive.** OCCT's `GProp_PGProps::AddPoint` throws on the
    /// first weight that is not, and one bad weight discards the whole set rather than skipping
    /// that point. The result used to come back as mass 0 with a centroid of (0,0,0), which reads
    /// as a successful answer (#609).
    ///
    /// ```swift
    /// let pts = [SIMD3(0.0,0,0), SIMD3(10.0,0,0)]
    /// GeometryProperties.weightedCentroid(points: pts, weights: [1, 3]).centroid  // (7.5,0,0)
    /// GeometryProperties.weightedCentroid(points: pts, weights: [1, 0]).centroid  // nil, rejected
    /// GeometryProperties.weightedCentroid(points: pts, weights: [1]).centroid     // nil, length mismatch
    /// ```
    public static func weightedCentroid(points: [SIMD3<Double>], weights: [Double]) -> (
        mass: Double, centroid: SIMD3<Double>?
    ) {
        guard points.count == weights.count else { return (0, nil) }
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        let mass = OCCTGPropPointSetWeightedCentroid(
            flat, weights, Int32(points.count), &cx, &cy, &cz)
        return (mass, mass == 0 ? nil : SIMD3(cx, cy, cz))
    }

    /// Compute barycentre (equal weights) of a point set, or nil for an empty set.
    ///
    /// ```swift
    /// GeometryProperties.barycentre([SIMD3(0,0,0), SIMD3(4,0,0)])  // (2,0,0)
    /// GeometryProperties.barycentre([])                            // nil, was (0,0,0)
    /// ```
    public static func barycentre(_ points: [SIMD3<Double>]) -> SIMD3<Double>? {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        var cx = 0.0
        var cy = 0.0
        var cz = 0.0
        guard OCCTGPropBarycentre(flat, Int32(points.count), &cx, &cy, &cz) else { return nil }
        return SIMD3(cx, cy, cz)
    }
}
