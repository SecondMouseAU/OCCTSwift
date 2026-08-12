// ShapeMeasurements.swift
// OCCTSwift
//
// Per-face area / centroid / perimeter + per-edge length reports for
// dimension widgets, BOM extractors, and other measurement-driven UIs.

import simd

/// Measurements computed from the topology of a `Shape`, indexed parallel to its
/// face / edge enumeration so consumers (e.g. AIS-layer dimension widgets)
/// can resolve a picked face / edge index directly to its scalar measurement.
public struct ShapeMeasurements: Sendable {
    /// `faceAreas[i]` is the area of `shape.faces()[i]`.
    public let faceAreas: [Double]

    /// `edgeLengths[i]` is the arc length of `shape.edge(at: i)` (0..<shape.edgeCount).
    public let edgeLengths: [Double]

    /// `faceCentroids[i]` is the surface center-of-mass of `shape.faces()[i]`,
    /// computed via `BRepGProp_Sinert`, or `nil` when that face has no area to have a centroid.
    ///
    /// Optional since #609, and for the same reason `facePerimeters` always was: a zero-area face
    /// reported (0,0,0), which a dimension widget cannot tell apart from a face genuinely centred
    /// on the origin. The entry is nil rather than dropped so the array stays index-parallel with
    /// `shape.faces()`.
    public let faceCentroids: [SIMD3<Double>?]

    /// `facePerimeters[i]` is the outer-wire length of `shape.faces()[i]`, or
    /// `nil` if the face has no outer wire or wire length is unavailable.
    ///
    /// **Caveat**: this is the *outer-boundary* length, not a parametric arc
    /// length. For trimmed faces (a face with internal holes), this excludes
    /// the inner-wire perimeters — usually what dimension widgets want, but
    /// worth knowing.
    public let facePerimeters: [Double?]

    public init(
        faceAreas: [Double],
        edgeLengths: [Double],
        faceCentroids: [SIMD3<Double>?] = [],
        facePerimeters: [Double?] = []
    ) {
        self.faceAreas = faceAreas
        self.edgeLengths = edgeLengths
        self.faceCentroids = faceCentroids
        self.facePerimeters = facePerimeters
    }

    /// Sum of all face areas.
    ///
    /// Convenience over `faceAreas.reduce(0, +)`: N independently-toleranced per-face
    /// integrals (``Face/area(tolerance:)``, tunable via ``Shape/measure(linearTolerance:)``).
    ///
    /// **Not the same computation as** ``Shape/surfaceArea``, ``Shape/surfaceInertiaProperties()``
    /// `.mass` or ``Shape/surfaceInertia`` `.area` (#885): those three share one aggregate,
    /// untunable, whole-shape integral, so this total and theirs can disagree — usually by an
    /// amount too small to matter, but tightening `linearTolerance` moves only this one. See
    /// ``Shape/measure(linearTolerance:)`` for the measured gap and which total to reach for.
    public var totalFaceArea: Double { faceAreas.reduce(0, +) }

    /// Sum of all edge lengths.
    public var totalEdgeLength: Double { edgeLengths.reduce(0, +) }

    /// Sum of all available face perimeters (`nil` entries are skipped).
    public var totalFacePerimeter: Double {
        facePerimeters.reduce(0) { acc, p in acc + (p ?? 0) }
    }
}

extension Shape {
    /// Compute per-face area / centroid / perimeter + per-edge length for this shape.
    ///
    /// `linearTolerance` only ever moves ``ShapeMeasurements/faceAreas`` and
    /// ``ShapeMeasurements/totalFaceArea`` (#885): it is forwarded to the adaptive, per-face
    /// ``Face/area(tolerance:)``, while ``Shape/surfaceArea``, ``Shape/surfaceInertiaProperties()``
    /// `.mass` and ``Shape/surfaceInertia`` `.area` share one untunable, whole-shape integral that
    /// this parameter cannot reach. At the default `1e-6` the two agree to ~12 significant figures
    /// on ordinary shapes (measured on a radius-10 sphere: `1256.637061435917` vs
    /// `1256.6370614359175`), so tightening `linearTolerance` to "fix" a mismatch just makes this
    /// total diverge *further* from the other, unmoved, one. Past `linearTolerance = 0.001`,
    /// `BRepGProp::SurfaceProperties`'s own adaptive integration gives way to a non-adaptive mode
    /// (documented on the OCCT call itself), and the gap can become real: the same sphere measured
    /// `1216.31...` at `linearTolerance: 0.5` against the other three's fixed `1256.64...`, a ~3.2%
    /// difference, not floating-point noise.
    /// - Parameter linearTolerance: tolerance forwarded to `Face.area(tolerance:)`.
    ///   Defaults to OCCT's `1e-6` — tighten only if you hit precision issues, and see above for
    ///   why tightening past that point does not converge ``ShapeMeasurements/totalFaceArea``
    ///   toward ``Shape/surfaceArea``.
    /// - Returns: A `ShapeMeasurements` snapshot with all four arrays populated and indexed
    ///   parallel to the shape's face/edge enumeration.
    public func measure(linearTolerance: Double = 1e-6) -> ShapeMeasurements {
        let faceList = faces()
        let faceAreas = faceList.map { $0.area(tolerance: linearTolerance) }
        let faceCentroids = faceList.map { $0.surfaceInertia.centerOfMass }
        let facePerimeters: [Double?] = faceList.map { $0.outerWire?.length }

        let count = edgeCount
        var edgeLengths: [Double] = []
        edgeLengths.reserveCapacity(count)
        for i in 0..<count {
            edgeLengths.append(edge(at: i)?.length ?? 0)
        }

        return ShapeMeasurements(
            faceAreas: faceAreas,
            edgeLengths: edgeLengths,
            faceCentroids: faceCentroids,
            facePerimeters: facePerimeters
        )
    }
}
