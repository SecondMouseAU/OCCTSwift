import Foundation
import simd

// MARK: - Drawing transform + bounds (#75, v0.144)
//
// Multi-view sheet composition needs a way to place drawings at different
// positions and scales on the same sheet. `TransformedDrawing` wraps a
// `Drawing` + uniform scale + 2D translate; `DXFWriter.collectFromDrawing`
// knows how to emit its edges and annotations with the transform applied.
// `Drawing.transformed(translate:scale:)` is the sugar call.

public struct TransformedDrawing: @unchecked Sendable {
    public let source: Drawing
    public let translate: SIMD2<Double>
    public let scale: Double

    public init(source: Drawing, translate: SIMD2<Double> = .zero, scale: Double = 1.0) {
        self.source = source
        self.translate = translate
        self.scale = scale
    }

    public func apply(_ p: SIMD2<Double>) -> SIMD2<Double> {
        Self.apply(p, translate: translate, scale: scale)
    }

    /// The 2D affine transform every drawing-transform site shares: `scale * p + translate`.
    ///
    /// Kept as one `internal` implementation, called by the instance method above and by
    /// `DrawingDimension.transformed`/`DrawingAnnotation.transformed` (`DrawingComposition.swift`)
    /// and `collectProjectedEdges` (`DrawingDispatch.swift`), instead of re-derived at each site,
    /// so a future change to the formula (e.g. adding rotation) is made once. #1183.
    internal static func apply(_ p: SIMD2<Double>, translate: SIMD2<Double>, scale: Double)
        -> SIMD2<Double>
    {
        scale * p + translate
    }
}

extension Drawing {
    /// Return a `TransformedDrawing` wrapping this drawing with a uniform scale
    /// and 2D translate.
    ///
    /// Composition pattern:
    ///
    /// ```swift
    /// for (view, placement) in layout {
    ///     writer.collectFromDrawing(view.transformed(translate: placement.offset,
    ///                                                 scale: placement.scale))
    /// }
    /// ```
    public func transformed(translate: SIMD2<Double>, scale: Double = 1.0) -> TransformedDrawing {
        TransformedDrawing(source: self, translate: translate, scale: scale)
    }

    /// 2D axis-aligned bounding box of the drawing's visible / hidden / outline
    /// edges, optionally including annotation extents.
    ///
    /// Returns nil if the drawing contains no geometry.
    public func bounds(
        deflection: Double = 0.1,
        includeAnnotations: Bool = true
    ) -> (min: SIMD2<Double>, max: SIMD2<Double>)? {
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        func include(_ points: [SIMD2<Double>]) {
            for p in points {
                minX = min(minX, p.x)
                minY = min(minY, p.y)
                maxX = max(maxX, p.x)
                maxY = max(maxY, p.y)
            }
        }

        for compound in [visibleEdges, hiddenEdges, outlineEdges] {
            guard let compound else { continue }
            for polyline in compound.allEdgePolylines(deflection: deflection) {
                include(polyline.map { SIMD2($0.x, $0.y) })
            }
        }
        if includeAnnotations {
            for dim in annotationStore.dimensions {
                include(dim.keyPoints)
            }
            for ann in annotationStore.annotations {
                include(ann.keyPoints)
            }
        }
        guard minX.isFinite, maxX.isFinite else { return nil }
        return (min: SIMD2(minX, minY), max: SIMD2(maxX, maxY))
    }
}

// MARK: - Annotation transforms (used by DXFWriter)

extension DrawingDimension {
    internal func transformed(translate: SIMD2<Double>, scale: Double) -> DrawingDimension {
        func t(_ p: SIMD2<Double>) -> SIMD2<Double> {
            TransformedDrawing.apply(p, translate: translate, scale: scale)
        }
        switch self {
        case .linear(var d):
            d.from = t(d.from)
            d.to = t(d.to)
            d.offset *= scale
            return .linear(d)
        case .radial(var d):
            d.centre = t(d.centre)
            d.radius *= scale
            return .radial(d)
        case .diameter(var d):
            d.centre = t(d.centre)
            d.radius *= scale
            return .diameter(d)
        case .angular(var d):
            d.vertex = t(d.vertex)
            d.ray1 = t(d.ray1)
            d.ray2 = t(d.ray2)
            d.arcRadius *= scale
            return .angular(d)
        case .ordinate(var d):
            d.origin = t(d.origin)
            d.features = d.features.map { feature in
                var f = feature
                f.position = t(f.position)
                return f
            }
            return .ordinate(d)
        }
    }

    internal var keyPoints: [SIMD2<Double>] {
        switch self {
        case .linear(let d): return [d.from, d.to]
        case .radial(let d):
            return [
                d.centre,
                SIMD2(d.centre.x + d.radius, d.centre.y),
                SIMD2(d.centre.x - d.radius, d.centre.y),
            ]
        case .diameter(let d):
            return [
                d.centre,
                SIMD2(d.centre.x + d.radius, d.centre.y),
                SIMD2(d.centre.x - d.radius, d.centre.y),
            ]
        case .angular(let d): return [d.vertex, d.ray1, d.ray2]
        case .ordinate(let d): return [d.origin] + d.features.map { $0.position }
        }
    }
}

extension DrawingAnnotation {
    internal func transformed(translate: SIMD2<Double>, scale: Double) -> DrawingAnnotation {
        func t(_ p: SIMD2<Double>) -> SIMD2<Double> {
            TransformedDrawing.apply(p, translate: translate, scale: scale)
        }
        switch self {
        case .centreline(var c):
            c.from = t(c.from)
            c.to = t(c.to)
            return .centreline(c)
        case .centermark(var m):
            m.centre = t(m.centre)
            m.extent *= scale
            return .centermark(m)
        case .textLabel(var label):
            label.position = t(label.position)
            label.height *= scale
            return .textLabel(label)
        case .hatch(var h):
            h.boundary = h.boundary.map(t)
            h.islands = h.islands.map { $0.map(t) }
            h.spacing *= scale
            return .hatch(h)
        case .cuttingPlaneLine(var cpl):
            cpl.traceStart = t(cpl.traceStart)
            cpl.traceEnd = t(cpl.traceEnd)
            // Arrow direction is a unit vector; uniform scale preserves direction.
            return .cuttingPlaneLine(cpl)
        case .balloon(var b):
            b.centre = t(b.centre)
            b.radius *= scale
            if let leader = b.leaderTo { b.leaderTo = t(leader) }
            return .balloon(b)
        case .arc(var a):
            a.centre = t(a.centre)
            a.radius *= scale
            return .arc(a)
        }
    }

    internal var keyPoints: [SIMD2<Double>] {
        switch self {
        case .centreline(let c): return [c.from, c.to]
        case .centermark(let m): return [m.centre]
        case .textLabel(let t): return [t.position]
        case .hatch(let h): return h.boundary
        case .cuttingPlaneLine(let c): return [c.traceStart, c.traceEnd]
        case .balloon(let b):
            var pts = [b.centre]
            if let leader = b.leaderTo { pts.append(leader) }
            return pts
        case .arc(let a):
            return [
                a.centre,
                SIMD2(
                    a.centre.x + a.radius * cos(a.startAngle),
                    a.centre.y + a.radius * sin(a.startAngle)),
                SIMD2(
                    a.centre.x + a.radius * cos(a.endAngle),
                    a.centre.y + a.radius * sin(a.endAngle)),
            ]
        }
    }
}
