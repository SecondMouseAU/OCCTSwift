import Foundation
import OCCTBridge
import simd

// MARK: - Ray Hit Result

/// Result from a ray cast against a shape.
public struct RayHit: Sendable {
    /// 3D point where ray intersects surface.
    public let point: SIMD3<Double>

    /// Surface normal at intersection point.
    ///
    /// `(0, 0, 1)` where the surface has no normal at the hit point — check ``normalDefined``
    /// rather than reading an upward normal as a fact about the geometry.
    public let normal: SIMD3<Double>

    /// Index of the face that was hit (0-based).
    public let faceIndex: Int

    /// Distance from ray origin to intersection point.
    public let distance: Double

    /// UV parameters on the surface at intersection.
    public let uv: SIMD2<Double>

    /// Whether ``normal`` is the surface's own normal or the `(0, 0, 1)` fallback.
    ///
    /// False only at a genuinely singular point of the surface. Until #529 it was also false
    /// whenever `tolerance` was raised past about 1, because the intersection tolerance doubled as
    /// the local-property resolution, where it is a dimensionless sine tolerance.
    public let normalDefined: Bool
}

// MARK: - Shape Ray Casting Extension

extension Shape {
    /// Cast a ray against the shape and find all intersections.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)
    /// for hit in box.raycast(origin: SIMD3(0, 0, 20), direction: SIMD3(0, 0, -1)) {
    ///     print("\(hit.distance) away, normal \(hit.normalDefined ? "\(hit.normal)" : "undefined")")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - origin: Starting point of the ray
    ///   - direction: Direction of the ray (will be normalized)
    ///   - tolerance: Intersection tolerance (default: 0.001). Since #529 this bounds the
    ///     intersection only; the surface normal reported for each hit is computed at the same
    ///     resolution as every other local-property call, so raising it no longer erases normals.
    ///   - maxHits: Output *capacity* (default: 100), clamped into `0...`
    ///     ``Sampling/maximumSampleCount``; 0 or less returns empty (#622). The ray decides how
    ///     many surfaces it actually crosses, so this only truncates — clamping an unservable
    ///     capacity returns the same hits, not a coarser set.
    /// - Returns: Array of ray hits sorted by distance
    public func raycast(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        tolerance: Double = 0.001,
        maxHits: Int = 100
    ) -> [RayHit] {
        let capacity = Sampling.capacity(maxHits)
        guard capacity > 0 else { return [] }

        // Allocate buffer for hits
        var hitBuffer = [OCCTRayHit](repeating: OCCTRayHit(), count: capacity)

        let hitCount = OCCTShapeRaycast(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            tolerance,
            &hitBuffer,
            Int32(capacity)
        )

        guard hitCount > 0 else { return [] }

        // Convert to Swift structs
        var results = [RayHit]()
        results.reserveCapacity(Int(hitCount))

        for i in 0..<Int(hitCount) {
            let hit = hitBuffer[i]
            results.append(
                RayHit(
                    point: SIMD3(hit.point.0, hit.point.1, hit.point.2),
                    normal: SIMD3(hit.normal.0, hit.normal.1, hit.normal.2),
                    faceIndex: Int(hit.faceIndex),
                    distance: hit.distance,
                    uv: SIMD2(hit.uv.0, hit.uv.1),
                    normalDefined: hit.normalDefined
                ))
        }

        // Sort by distance (nearest first)
        results.sort { $0.distance < $1.distance }

        return results
    }

    /// Cast a ray and return only the nearest hit.
    /// - Parameters:
    ///   - origin: Starting point of the ray
    ///   - direction: Direction of the ray
    ///   - tolerance: Intersection tolerance
    /// - Returns: Nearest hit, or nil if no intersection
    public func raycastNearest(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        tolerance: Double = 0.001
    ) -> RayHit? {
        raycast(origin: origin, direction: direction, tolerance: tolerance, maxHits: 100).first
    }
}

// MARK: - Shape Face Index Access Extension

extension Shape {
    /// The number of distinct faces in this shape.
    ///
    /// This is the same enumeration ``faces()`` walks and ``face(at:)`` indexes: one entry per
    /// distinct face, in `TopExp_Explorer` order, addressed from 0. A face reachable from two
    /// parents — the wall shared by both halves of a split solid, say — counts once.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// print(box.faceCount)                     // 6
    /// print(box.faces().count)                 // 6, the same enumeration
    /// print(box.subShapeCount(ofType: .face))  // 6, the generic spelling
    /// ```
    ///
    /// ``nbFaces`` was a second spelling of this same question, backed by a bare
    /// `TopExp_Explorer` occurrence walk instead of this deduplicated count, and is deprecated in
    /// favour of this one (#651).
    public var faceCount: Int {
        Int(OCCTShapeGetFaceCount(handle))
    }

    /// The face at a 0-based index in this shape's face enumeration.
    ///
    /// The index is the one ``Face/index`` carries, and the one every face-index-taking method on
    /// `Shape` expects. It is meaningful only against the shape it came from: an index taken from
    /// one shape and used on another names an unrelated face, or nothing at all.
    ///
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)!
    /// for face in box.faces() {
    ///     // Every index faces() hands out is addressable here, and names the same face.
    ///     let again = box.face(at: face.index)!
    ///     print(face.index, again.area())
    /// }
    /// print(box.face(at: box.faceCount) as Any)   // nil — one past the end
    /// ```
    ///
    /// - Parameter index: The face index, in `0..<faceCount`.
    /// - Returns: Face at the given index, or nil if the index is out of bounds.
    public func face(at index: Int) -> Face? {
        guard let faceHandle = OCCTShapeGetFaceAtIndex(handle, Int32(index)) else {
            return nil
        }
        return Face(handle: faceHandle, index: index)
    }
}
