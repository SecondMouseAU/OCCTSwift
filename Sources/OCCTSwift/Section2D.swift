import Foundation
import simd

// MARK: - Shape.section2D (#73, v0.144)
//
// Slice a shape with a plane and return the resulting contour as a `Drawing`
// in the plane's own 2D coordinate frame. Composes over existing primitives:
// `Shape.sectionWithPlane` → world-space edge compound, then projects each
// 3D sample point onto the (u, v) frame of the cutting plane.
//
// Useful for:
//   - Emitting section views on a drawing sheet (paired with #74 hatching)
//   - Feeding shape-derived contours into DXF export without a full HLR pass
//   - Cross-section preview in a viewport

extension Shape {
    /// Slice this shape with a plane and return the contour as a 2D Drawing.
    /// in the plane's own coordinate frame.
    ///
    /// The plane's u axis (derived from planeU if supplied, otherwise.
    /// `perpendicularBasis(to:)`'s canonical perpendicular) becomes the
    /// Drawing's X axis; its v axis (u × normal) becomes Y.
    ///
    /// Each 3D.
    /// contour point p is projected as `(u · (p − origin), v · (p − origin))`.
    ///
    /// - Parameters:
    ///   - planeOrigin: Any point on the cutting plane, in world coordinates.
    ///   - planeNormal: Plane normal.
    ///
    ///   Will be normalised.
    ///   - planeU: Explicit X axis for the resulting 2D frame.
    ///
    ///   Must be.
    ///     perpendicular to planeNormal.
    ///
    ///     When nil (default), the perpendicular.
    ///     is derived deterministically via `perpendicularBasis(to:)`.
    ///   - deflection: Tessellation tolerance for edge sampling. ISO-quality
    ///     section drawings typically use 0.01–0.1 mm.
    /// - Returns: A Drawing whose visibleEdges contain the 2D contour
    ///   polylines.
    ///
    ///   Dimensions, centrelines, hatching etc. can be added via.
    ///   the normal Drawing API.
    ///
    ///   Returns nil if the plane doesn't intersect.
    ///   the shape or projection fails.
    public func section2D(
        planeOrigin: SIMD3<Double>,
        planeNormal: SIMD3<Double>,
        planeU: SIMD3<Double>? = nil,
        deflection: Double = 0.1
    ) -> Drawing? {
        guard let contour = sectionWithPlane(normal: planeNormal, origin: planeOrigin) else {
            return nil
        }
        let (u, v) = Self.sectionPlaneBasis(normal: planeNormal, explicitU: planeU)

        // Collect polylines from the 3D contour, project each to 2D.
        let polys3D = contour.allEdgePolylines(deflection: deflection)
        guard !polys3D.isEmpty else { return nil }

        // Build a compound of 2D edges as a Shape, then hand it to Drawing via
        // the standard projection path. We sidestep OCCT's HLR here because the
        // contour is already 2D, we just need a Drawing whose `visibleEdges`
        // carries our polylines.
        //
        // Strategy: project along `planeNormal` starting from a shape compound
        // we construct from the 2D contour points lifted into the world's XY
        // plane. This reuses `Drawing.project` machinery so annotations and
        // auto-centrelines work downstream.
        var wires: [Wire] = []
        for poly in polys3D {
            guard poly.count >= 2 else { continue }
            let points2D = poly.map { p3 -> SIMD3<Double> in
                let offset = p3 - planeOrigin
                let x = simd_dot(offset, u)
                let y = simd_dot(offset, v)
                return SIMD3(x, y, 0)
            }
            if let w = Wire.polygon3D(points2D, closed: false) {
                wires.append(w)
            }
        }
        guard !wires.isEmpty else { return nil }

        // Compose wires into a single compound for projection.
        let compoundShape = Shape.compound(from: wires.compactMap { Shape.shape(from: $0) })
        // Project along Z to get a Drawing whose visibleEdges are our 2D contour.
        guard let compoundShape,
            let drawing = Drawing.project(compoundShape, direction: SIMD3(0, 0, 1))
        else {
            return nil
        }
        return drawing
    }

    /// Derive a deterministic orthonormal basis (u, v) in the plane defined by.
    /// normal and the optional explicit u direction.
    internal static func sectionPlaneBasis(
        normal: SIMD3<Double>,
        explicitU: SIMD3<Double>?
    ) -> (SIMD3<Double>, SIMD3<Double>) {
        let n = simd_normalize(normal)
        let u: SIMD3<Double>
        let v: SIMD3<Double>
        if let explicit = explicitU {
            u = simd_normalize(explicit - simd_dot(explicit, n) * n)
            v = simd_normalize(simd_cross(n, u))
        } else {
            // perpendicularBasis(to:)'s own `up` is already `normalize(cross(v, right))` with
            // `v == n` and `right == u` here, i.e. bit-for-bit `simd_normalize(simd_cross(n, u))`
            //, so the explicit-`u` branch's cross product is redundant in this branch and would
            // just recompute the same answer a second time (#914 review, second round).
            (u, v) = perpendicularBasis(to: n)
        }
        return (u, v)
    }

    /// Compound a list of shapes into one.
    ///
    /// Convenience for Section2D assembly; returns nil on empty input.
    internal static func compound(from shapes: [Shape]) -> Shape? {
        guard !shapes.isEmpty else { return nil }
        if shapes.count == 1 { return shapes[0] }
        // Fuse sequentially using union; adequate for edge compounds where the
        // pieces don't truly intersect as solids.
        var result: Shape = shapes[0]
        for s in shapes.dropFirst() {
            if let u = result.union(s) { result = u }
        }
        return result
    }
}

/// A section view spec, contour + optional hatch + optional label, bundled.
/// for convenient composition onto a sheet. `Shape.section2DView(...)` wraps.
/// section2D with automatic hatching and an "A-A" label, matching ISO 128-40.
extension Shape {
    public struct SectionView: Sendable {
        public let drawing: Drawing
        public let label: String?
        public let cuttingPlaneOrigin: SIMD3<Double>
        public let cuttingPlaneNormal: SIMD3<Double>
    }

    /// ISO 128-40-styled section view: slice + hatching + label bundled into a
    /// single Drawing ready to place on a sheet.
    public func section2DView(
        planeOrigin: SIMD3<Double>,
        planeNormal: SIMD3<Double>,
        label: String? = nil,
        hatchAngle: Double = .pi / 4,
        hatchSpacing: Double = 3.0,
        deflection: Double = 0.1
    ) -> SectionView? {
        guard
            let drawing = section2D(
                planeOrigin: planeOrigin,
                planeNormal: planeNormal,
                deflection: deflection)
        else { return nil }
        // Hatch the outer boundary (best-effort, uses the drawing's own bounds
        // as the boundary polygon for now; full contour-based hatching comes
        // when we have polygon identification of section interiors).
        if let bounds = drawing.bounds() {
            let boundary = [
                SIMD2(bounds.min.x, bounds.min.y),
                SIMD2(bounds.max.x, bounds.min.y),
                SIMD2(bounds.max.x, bounds.max.y),
                SIMD2(bounds.min.x, bounds.max.y),
            ]
            drawing.addHatch(boundary: boundary, angle: hatchAngle, spacing: hatchSpacing)
        }
        if let label = label, let bounds = drawing.bounds() {
            drawing.addTextLabel(
                label,
                at: SIMD2(bounds.min.x, bounds.max.y + 5),
                height: 5.0)
        }
        return SectionView(
            drawing: drawing,
            label: label,
            cuttingPlaneOrigin: planeOrigin,
            cuttingPlaneNormal: planeNormal)
    }
}
