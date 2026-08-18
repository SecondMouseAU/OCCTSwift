import Foundation
import simd

// MARK: - Auto dimensioning (#83, v0.149)
//
// Given a `Drawing` already projected from `shape`, heuristically add the
// dimensions a reader expects on any engineering view: overall width/height of
// the in-view bounding box plus a diameter on every visible circular edge.
//
// The goal isn't to replace a drafter's judgement — it's to get an agent-driven
// drawing from "unannotated projection" to "readable" in one call. Callers that
// want finer control still reach for `addLinearDimension` / `addDiameterDimension`
// directly.

extension Drawing {
    public struct AutoDimensionResult: Sendable {
        public let added: [DrawingDimension]
        /// Human-readable reasons for edges/features that were skipped —
        /// useful for debugging why a hole didn't get dimensioned.
        public let skipped: [String]
    }

    /// Heuristic dimensions: overall X+Y extent of the shape's projected
    /// bounding box, plus a diameter dimension on every visible circular edge
    /// whose radius is at least `minRadius`.
    ///
    /// - Parameters:
    ///   - shape: Source 3D shape (the one this drawing was projected from).
    ///   - viewDirection: Same vector passed to `Drawing.project(_:direction:)`;
    ///     assumed unit-length.
    ///   - minRadius: Circles smaller than this are skipped.
    ///   - dimensionOffset: Distance (drawing units) between the view and
    ///     the dimension line for overall extents.
    ///   - bounds: Optional 2D clipping rectangle; when non-nil, circles
    ///     whose projected centre falls outside the rectangle are skipped.
    /// - Returns: The dimensions added, and a reason string for each one skipped.
    @discardableResult
    public func addAutoDimensions(
        from shape: Shape,
        viewDirection: SIMD3<Double>,
        minRadius: Double = 0.1,
        dimensionOffset: Double = 10,
        bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil
    ) -> AutoDimensionResult {
        let viewZ = simd_normalize(viewDirection)
        var added: [DrawingDimension] = []
        var skipped: [String] = []

        // --- 1. Overall extents from shape's 3D bounding box ---
        // A shape with no bounding box (#943) has no overall extents to dimension. Step 2 below
        // does not read the box, so it still runs: this skips the extents, not the whole call.
        if let bb3 = shape.bounds {
            let corners3D: [SIMD3<Double>] = [
                SIMD3(bb3.min.x, bb3.min.y, bb3.min.z),
                SIMD3(bb3.max.x, bb3.min.y, bb3.min.z),
                SIMD3(bb3.min.x, bb3.max.y, bb3.min.z),
                SIMD3(bb3.max.x, bb3.max.y, bb3.min.z),
                SIMD3(bb3.min.x, bb3.min.y, bb3.max.z),
                SIMD3(bb3.max.x, bb3.min.y, bb3.max.z),
                SIMD3(bb3.min.x, bb3.max.y, bb3.max.z),
                SIMD3(bb3.max.x, bb3.max.y, bb3.max.z),
            ]
            let corners2D = corners3D.map { projectPointToPlane($0, viewDirection: viewZ) }
            if corners2D.isEmpty {
                skipped.append("empty bounding box")
            } else {
                let xs = corners2D.map(\.x)
                let ys = corners2D.map(\.y)
                let minX = xs.min() ?? 0
                let maxX = xs.max() ?? 0
                let minY = ys.min() ?? 0
                let maxY = ys.max() ?? 0
                let width = maxX - minX
                let height = maxY - minY

                if width > 1e-9 {
                    let dim = addLinearDimension(
                        from: SIMD2(minX, minY),
                        to: SIMD2(maxX, minY),
                        offset: -dimensionOffset,
                        id: "auto-width")
                    added.append(dim)
                } else {
                    skipped.append("zero-width projected extent")
                }

                if height > 1e-9 {
                    let dim = addLinearDimension(
                        from: SIMD2(minX, minY),
                        to: SIMD2(minX, maxY),
                        offset: dimensionOffset,
                        id: "auto-height")
                    added.append(dim)
                } else {
                    skipped.append("zero-height projected extent")
                }
            }
        } else {
            skipped.append("shape has no bounding box")
        }

        // --- 2. Diameter dimensions on visible circular edges ---
        var diameterIndex = 0
        for edge in shape.edges() where edge.curveType == .circle {
            guard let curve = edge.curve3D else {
                skipped.append("circle edge has no curve3D")
                continue
            }
            let props = curve.circleProperties
            guard props.radius >= minRadius else {
                skipped.append("circle radius \(props.radius) < minRadius")
                continue
            }
            // Edge-on test: if the circle's plane normal is perpendicular to
            // the view direction (dot ≈ 0), the circle projects to a line
            // segment, not a circle — skip. Mirrors addAutoCentermarks.
            let normal = simd_cross(props.xAxis.direction, props.yAxis.direction)
            let dotAxis = abs(simd_dot(simd_normalize(normal), viewZ))
            if dotAxis < 0.1 {
                skipped.append("circle edge-on in view")
                continue
            }
            let centre2D = projectPointToPlane(props.center, viewDirection: viewZ)
            if let bb = bounds,
                centre2D.x < bb.min.x || centre2D.x > bb.max.x || centre2D.y < bb.min.y
                    || centre2D.y > bb.max.y
            {
                skipped.append("circle outside bounds")
                continue
            }
            let dim = addDiameterDimension(
                centre: centre2D,
                radius: props.radius,
                leaderAngle: .pi / 4,
                id: "auto-dia-\(diameterIndex)")
            added.append(dim)
            diameterIndex += 1
        }

        return AutoDimensionResult(added: added, skipped: skipped)
    }
}
