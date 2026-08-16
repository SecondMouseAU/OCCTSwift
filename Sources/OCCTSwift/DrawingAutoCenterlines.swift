import Foundation
import simd

// MARK: - Auto-centreline generation from #65 revolution axes
//
// Given a Drawing produced by projecting a Shape, extend the drawing with
// centrelines corresponding to the shape's axes of revolution. The axis is
// projected into the view plane and clipped to the drawing's 2D bounding box
// with a configurable overshoot.

extension Drawing {
    /// Result of auto-centreline generation, returned separately so callers can
    /// inspect what was added without re-querying `annotations`.
    public struct AutoCentrelineResult: Sendable {
        public let added: [DrawingAnnotation]
        public let skipped: [ShapeAxis]  // axes that projected to a point in view
    }

    /// Project the shape's axes of revolution into this drawing's view plane and
    /// add them as `.chain` centrelines.
    ///
    /// - Parameters:
    ///   - shape: The source 3D shape (typically the one this drawing was projected from).
    ///   - viewDirection: The projection direction used to create this drawing. Pass the same
    ///     vector you used for `Drawing.project(_:direction:)`; assumed unit-length.
    ///   - overshoot: Extra length (drawing units) added past the drawing bounding box on
    ///     both ends of the projected axis. Default 5.
    ///   - tolerance: Axis-deduplication tolerance passed to `Shape.revolutionAxes`.
    ///   - bounds: Optional override for the 2D bounding box used for clipping. When nil,
    ///     falls back to a sensible default (±1000 square centred at origin) — the caller
    ///     should pass the drawing's actual bbox when it's known.
    /// - Returns: The added centrelines plus any axes skipped because they projected to a point.
    @discardableResult
    public func addAutoCentrelines(
        from shape: Shape,
        viewDirection: SIMD3<Double>,
        overshoot: Double = 5,
        tolerance: Double = 1e-6,
        bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil
    ) -> AutoCentrelineResult {
        let axes = shape.revolutionAxes(tolerance: tolerance)
        let bb = bounds ?? (min: SIMD2(-1000, -1000), max: SIMD2(1000, 1000))
        var added: [DrawingAnnotation] = []
        var skipped: [ShapeAxis] = []
        let viewZ = simd_normalize(viewDirection)

        for axis in axes {
            guard
                let (p1, p2) = projectAxisToPlane(
                    origin: axis.origin,
                    direction: axis.direction,
                    viewDirection: viewZ,
                    bounds: bb,
                    overshoot: overshoot)
            else {
                skipped.append(axis)
                continue
            }
            let ann = addCentreLine(from: p1, to: p2, id: "auto-\(axis.kind)-\(added.count)")
            added.append(ann)
        }
        return AutoCentrelineResult(added: added, skipped: skipped)
    }
}

// MARK: - Auto centermark generation (#79, v0.147)

extension Drawing {
    public struct AutoCentermarkResult: Sendable {
        public let added: [DrawingAnnotation]
        public let skipped: [Edge]  // edges whose circle projects edge-on
    }

    /// Walk the circular edges of `shape` and add a `.centermark` at each visible circle's
    /// projected centre.
    ///
    /// A circle is visible when its plane normal isn't parallel to the view direction.
    /// Complements `addAutoCentrelines`, which handles revolution axes.
    @discardableResult
    public func addAutoCentermarks(
        from shape: Shape,
        viewDirection: SIMD3<Double>,
        extent: Double = 8,
        minRadius: Double = 0,
        bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil
    ) -> AutoCentermarkResult {
        let viewZ = simd_normalize(viewDirection)
        var added: [DrawingAnnotation] = []
        var skipped: [Edge] = []
        for edge in shape.edges() where edge.curveType == .circle {
            guard let curve = edge.curve3D else { continue }
            let props = curve.circleProperties
            guard props.radius >= minRadius else { continue }
            // Circle normal = X axis × Y axis of the circle's local frame.
            let normal = simd_cross(props.xAxis.direction, props.yAxis.direction)
            // If the circle's plane is parallel to the view direction, the
            // circle projects to a line segment (edge-on). Skip.
            let dot = abs(simd_dot(simd_normalize(normal), viewZ))
            if dot < 0.1 {
                skipped.append(edge)
                continue
            }
            let centre2D = projectPointToPlane(props.center, viewDirection: viewZ)
            if let bb = bounds,
                centre2D.x < bb.min.x || centre2D.x > bb.max.x || centre2D.y < bb.min.y
                    || centre2D.y > bb.max.y
            {
                continue
            }
            let ann = addCentermark(
                centre: centre2D, extent: extent,
                id: "auto-mark-\(added.count)")
            added.append(ann)
        }
        return AutoCentermarkResult(added: added, skipped: skipped)
    }
}

// perpendicularBasis(to:) moved to PerpendicularBasis.swift (#914 review, second round) —
// module-wide, not drawing-specific: 3 of its 5 call sites are geometry/construction code, the
// same misplacement finding 11 fixed for the bridge-unwrap helpers this file never had.

/// Project a 3D point onto the 2D plane perpendicular to `viewDirection`, using
/// `perpendicularBasis(to:)` — the same perpendicular-axis algorithm `gp_Ax2` uses
/// to build the `HLRAlgo_Projector` `OCCTDrawingCreate` projects this drawing's own
/// edges with.
internal func projectPointToPlane(
    _ p: SIMD3<Double>,
    viewDirection: SIMD3<Double>
) -> SIMD2<Double> {
    let (right, up) = perpendicularBasis(to: viewDirection)
    return SIMD2(simd_dot(p, right), simd_dot(p, up))
}

/// Project a 3D axis (origin + direction) into the 2D plane perpendicular to
/// `viewDirection` and clip to the given bounds.
///
/// Returns nil if the axis projects to a point (i.e. it is parallel to the view direction). The
/// 2D coordinate frame matches `projectPointToPlane`'s: X along `perpendicularBasis(to:)`'s
/// `right`, Y along its `up`.
internal func projectAxisToPlane(
    origin: SIMD3<Double>,
    direction: SIMD3<Double>,
    viewDirection: SIMD3<Double>,
    bounds: (min: SIMD2<Double>, max: SIMD2<Double>),
    overshoot: Double
) -> (SIMD2<Double>, SIMD2<Double>)? {
    // Build a basis (right, up) perpendicular to viewDirection.
    let (right, up) = perpendicularBasis(to: viewDirection)

    // Project axis direction onto view plane. If it collapses to a point, skip.
    let dir2 = SIMD2(simd_dot(direction, right), simd_dot(direction, up))
    if simd_length(dir2) < 1e-9 { return nil }
    let dir2n = simd_normalize(dir2)
    let origin2 = SIMD2(simd_dot(origin, right), simd_dot(origin, up))

    // Parameterise the line as origin2 + t * dir2n and clip to bounds.
    var tMin = -Double.infinity
    var tMax = Double.infinity
    // X slab
    if abs(dir2n.x) > 1e-12 {
        let t1 = (bounds.min.x - origin2.x) / dir2n.x
        let t2 = (bounds.max.x - origin2.x) / dir2n.x
        tMin = max(tMin, min(t1, t2))
        tMax = min(tMax, max(t1, t2))
    } else if origin2.x < bounds.min.x || origin2.x > bounds.max.x {
        return nil
    }
    // Y slab
    if abs(dir2n.y) > 1e-12 {
        let t1 = (bounds.min.y - origin2.y) / dir2n.y
        let t2 = (bounds.max.y - origin2.y) / dir2n.y
        tMin = max(tMin, min(t1, t2))
        tMax = min(tMax, max(t1, t2))
    } else if origin2.y < bounds.min.y || origin2.y > bounds.max.y {
        return nil
    }
    if tMin >= tMax { return nil }
    let p1 = origin2 + (tMin - overshoot) * dir2n
    let p2 = origin2 + (tMax + overshoot) * dir2n
    return (p1, p2)
}
