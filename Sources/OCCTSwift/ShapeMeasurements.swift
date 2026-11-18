// ShapeMeasurements.swift
// OCCTSwift
//
// Per-face area / centroid / perimeter + per-edge length reports for
// dimension widgets, BOM extractors, and other measurement-driven UIs.

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
    /// the inner-wire perimeters, usually what dimension widgets want, but
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
    /// Diverges from ``Shape/surfaceArea`` (#885); see ``Shape/surfaceArea`` for the explanation.
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
    /// ``ShapeMeasurements/totalFaceArea``, never ``Shape/surfaceArea`` and its two siblings; see
    /// ``Shape/surfaceArea`` for why (#885).
    /// ## Cost
    ///
    /// Linear in the face and edge counts. The edge lengths are read off one ``edges()``
    /// enumeration, which maps the shape once. They used to come from ``edge(at:)`` in a loop,
    /// and each of those calls built the whole sub-shape map to read one entry, so the loop was
    /// quadratic and was most of this call: on a 3,888-edge shape, 1.4 to 2.5 s of a 1.6 to 2.8 s
    /// measurement (#3527). The result is the same array.
    ///
    /// ```swift
    /// let box = Shape.box(width: 2, height: 3, depth: 5)!
    /// let m = box.measure()
    /// print(m.edgeLengths.count)       // 12, one per distinct edge
    /// print(m.totalEdgeLength)         // 40.0 = 4 * (2 + 3 + 5)
    /// ```
    ///
    /// - Parameter linearTolerance: tolerance forwarded to `Face.area(tolerance:)`.
    ///   Defaults to OCCT's `1e-6`, tighten only if you hit precision issues.
    /// - Returns: A `ShapeMeasurements` snapshot with all four arrays populated and indexed
    ///   parallel to the shape's face/edge enumeration.
    public func measure(linearTolerance: Double = 1e-6) -> ShapeMeasurements {
        let faceList = faces()
        let faceAreas = faceList.map { $0.area(tolerance: linearTolerance) }
        let faceCentroids = faceList.map { $0.surfaceInertia.centerOfMass }
        let facePerimeters: [Double?] = faceList.map { $0.outerWire?.length }

        let count = edgeCount
        let edgeList = edges()
        let edgeLengths: [Double]
        if edgeList.count == count {
            edgeLengths = edgeList.map { $0.length }
        } else {
            // `edges()` answers an empty array for the whole shape if any one edge cannot be
            // built (#979), where this array has always read `0` for that edge alone and kept every
            // other entry. The bridge cannot produce such a hole today, so this branch is
            // unreachable on a real shape; it keeps the per-edge contract if that ever changes.
            edgeLengths = (0..<count).map { edge(at: $0)?.length ?? 0 }
        }

        return ShapeMeasurements(
            faceAreas: faceAreas,
            edgeLengths: edgeLengths,
            faceCentroids: faceCentroids,
            facePerimeters: facePerimeters
        )
    }
}
