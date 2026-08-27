import Foundation
import simd

// MARK: - Value types for 2D drawing dimensions and annotations
//
// These live entirely in Swift — they do NOT round-trip through OCCT's PrsDim /
// XCAFDoc display-dimension classes. That decision is deliberate and recorded on
// the release-plan tracking issue (#67): the v1 closed-loop workflow needs
// dimensions as data (to compare across reconstruction iterations and to hand to
// a DXF writer), not as AIS display objects. XDE-backed round-trip is on the
// v0.139 roadmap if and when STEP AP242 GD&T preservation becomes a requirement.

/// Standard technical-drawing linetypes.
///
/// Used when rendering a `DrawingDimension` or `DrawingAnnotation` to DXF, PDF, or a viewport.
public enum DrawingLineStyle: String, Sendable, Hashable, Codable {
    case solid
    case dashed  // hidden-line pattern
    case phantom  // long-dash + 2 short-dash
    case chain  // long-dash + short-dash (centreline)
    case dotted
}

/// Typed tolerance carried on a `DrawingDimension`.
///
/// Rendered inline for symmetric / fit-class cases, or as stacked TEXT (upper + lower) for
/// bilateral / unilateral / explicit-limits cases in DXF/PDF/SVG output.
///
/// The enum is the typed replacement for the old `label: "⌀10 ±0.05"` escape
/// hatch: a caller that wants structured tolerance data can set
/// `tolerance = .symmetric(0.05)` and keep `label` nil, letting the writer
/// compose the full text from `value` + `tolerance`.
public enum DrawingTolerance: Sendable, Hashable, Codable {
    /// No tolerance displayed.
    case none
    /// Symmetric ± tolerance: `20 ±0.05`.
    case symmetric(Double)
    /// Bilateral: `20 +0.10 / -0.05`. Both values are magnitudes; the
    /// writer adds the signs.
    case bilateral(plus: Double, minus: Double)
    /// Unilateral (single-sided): `20 +0.10 / 0` or `20 0 / -0.10`
    /// depending on sign of the value.
    case unilateral(Double)
    /// ISO 286 fit class appended as a suffix: `H7`, `g6`, `h7/H8`.
    case fitClass(String)
    /// Explicit upper / lower limits stacked over the nominal:
    /// `20 upper / lower` rendered on two lines.
    case limits(lower: Double, upper: Double)
}

/// A dimension attached to a `Drawing`.
///
/// Each case carries just the geometric definition needed to render it;
/// there's no OCCT handle inside.
public enum DrawingDimension: Sendable, Hashable {
    case linear(Linear)
    case radial(Radial)
    case diameter(Diameter)
    case angular(Angular)
    case ordinate(Ordinate)

    public struct Linear: Sendable, Hashable {
        public var from: SIMD2<Double>
        public var to: SIMD2<Double>
        /// Perpendicular offset of the dimension line from the measured segment (drawing units).
        public var offset: Double
        /// Optional user-supplied label; nil means auto-format the measured value.
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?
        public var tolerance: DrawingTolerance

        public init(
            from: SIMD2<Double>, to: SIMD2<Double>,
            offset: Double = 10, label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none
        ) {
            self.from = from
            self.to = to
            self.offset = offset
            self.label = label
            self.style = style
            self.id = id
            self.tolerance = tolerance
        }

        /// Measured 2D distance between `from` and `to`.
        public var value: Double { simd_distance(from, to) }
    }

    public struct Radial: Sendable, Hashable {
        public var centre: SIMD2<Double>
        public var radius: Double
        /// Angle (radians) at which the leader line exits the circle.
        public var leaderAngle: Double
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?
        public var tolerance: DrawingTolerance

        public init(
            centre: SIMD2<Double>, radius: Double,
            leaderAngle: Double = .pi / 4,
            label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none
        ) {
            self.centre = centre
            self.radius = radius
            self.leaderAngle = leaderAngle
            self.label = label
            self.style = style
            self.id = id
            self.tolerance = tolerance
        }

        public var value: Double { radius }
    }

    public struct Diameter: Sendable, Hashable {
        public var centre: SIMD2<Double>
        public var radius: Double
        public var leaderAngle: Double
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?
        public var tolerance: DrawingTolerance

        public init(
            centre: SIMD2<Double>, radius: Double,
            leaderAngle: Double = .pi / 4,
            label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none
        ) {
            self.centre = centre
            self.radius = radius
            self.leaderAngle = leaderAngle
            self.label = label
            self.style = style
            self.id = id
            self.tolerance = tolerance
        }

        public var value: Double { 2 * radius }
    }

    public struct Angular: Sendable, Hashable {
        /// Vertex at which the two rays meet.
        public var vertex: SIMD2<Double>
        public var ray1: SIMD2<Double>
        public var ray2: SIMD2<Double>
        /// Radius at which the dimension arc is drawn.
        public var arcRadius: Double
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?
        public var tolerance: DrawingTolerance

        public init(
            vertex: SIMD2<Double>, ray1: SIMD2<Double>, ray2: SIMD2<Double>,
            arcRadius: Double = 20,
            label: String? = nil,
            style: DrawingLineStyle = .solid, id: String? = nil,
            tolerance: DrawingTolerance = .none
        ) {
            self.vertex = vertex
            self.ray1 = ray1
            self.ray2 = ray2
            self.arcRadius = arcRadius
            self.label = label
            self.style = style
            self.id = id
            self.tolerance = tolerance
        }

        /// Measured angle between the two rays, in radians (0 ≤ θ ≤ π).
        public var value: Double {
            let v1 = simd_normalize(ray1 - vertex)
            let v2 = simd_normalize(ray2 - vertex)
            return acos(max(-1.0, min(1.0, simd_dot(v1, v2))))
        }
    }

    /// ISO 129-1 §9.3 ordinate dimensions: a shared origin plus N features,
    /// each shown as an X-offset (along the bottom of the view) and Y-offset
    /// (along the side) measured from the origin.
    ///
    /// Used for CNC-style reference-datum dimensioning where chains of linear
    /// dimensions would clutter the view.
    public struct Ordinate: Sendable, Hashable, Codable {
        public var origin: SIMD2<Double>
        public var features: [Feature]
        public var id: String?
        public var tolerance: DrawingTolerance

        public struct Feature: Sendable, Hashable, Codable {
            public var position: SIMD2<Double>
            /// Custom label text; nil means auto-format the (x, y) offset.
            public var label: String?
            public var id: String?

            public init(position: SIMD2<Double>, label: String? = nil, id: String? = nil) {
                self.position = position
                self.label = label
                self.id = id
            }
        }

        public init(
            origin: SIMD2<Double>, features: [Feature],
            tolerance: DrawingTolerance = .none, id: String? = nil
        ) {
            self.origin = origin
            self.features = features
            self.tolerance = tolerance
            self.id = id
        }
    }

    public var id: String? {
        switch self {
        case .linear(let d): return d.id
        case .radial(let d): return d.id
        case .diameter(let d): return d.id
        case .angular(let d): return d.id
        case .ordinate(let d): return d.id
        }
    }

    public var label: String? {
        switch self {
        case .linear(let d): return d.label
        case .radial(let d): return d.label
        case .diameter(let d): return d.label
        case .angular(let d): return d.label
        // Ordinate has per-feature labels; no single dimension-level label.
        case .ordinate: return nil
        }
    }

    public var value: Double {
        switch self {
        case .linear(let d): return d.value
        case .radial(let d): return d.value
        case .diameter(let d): return d.value
        case .angular(let d): return d.value
        // Ordinate has no single scalar measurement; callers should read
        // `features` instead.
        case .ordinate: return 0
        }
    }
}

/// Non-dimensional 2D annotations attached to a `Drawing` — centrelines, centremarks,
/// construction points, free-form text labels, hatch fills, assembly balloons.
public enum DrawingAnnotation: Sendable, Hashable {
    case centreline(Centreline)
    case centermark(Centermark)
    case textLabel(DrawingTextLabel)
    case hatch(Hatch)
    case cuttingPlaneLine(CuttingPlaneLine)
    case balloon(Balloon)
    case arc(Arc)

    public struct Centreline: Sendable, Hashable {
        public var from: SIMD2<Double>
        public var to: SIMD2<Double>
        public var style: DrawingLineStyle  // typically .chain
        public var id: String?

        public init(
            from: SIMD2<Double>, to: SIMD2<Double>,
            style: DrawingLineStyle = .chain,
            id: String? = nil
        ) {
            self.from = from
            self.to = to
            self.style = style
            self.id = id
        }
    }

    public struct Centermark: Sendable, Hashable {
        public var centre: SIMD2<Double>
        /// Full length of each of the two crossing line segments (drawing units).
        public var extent: Double
        public var style: DrawingLineStyle  // typically .chain
        public var id: String?

        public init(
            centre: SIMD2<Double>, extent: Double = 8,
            style: DrawingLineStyle = .chain,
            id: String? = nil
        ) {
            self.centre = centre
            self.extent = extent
            self.style = style
            self.id = id
        }
    }

    public struct DrawingTextLabel: Sendable, Hashable {
        public var position: SIMD2<Double>
        public var text: String
        public var height: Double
        public var rotation: Double  // radians
        public var id: String?

        public init(
            position: SIMD2<Double>, text: String,
            height: Double = 3.5, rotation: Double = 0,
            id: String? = nil
        ) {
            self.position = position
            self.text = text
            self.height = height
            self.rotation = rotation
            self.id = id
        }
    }

    /// ISO 128-40 cutting-plane line — the section mark on the parent view
    /// indicating where a section view was cut. Renders as:
    /// - heavy-chain segments at each endpoint (~10 mm long)
    /// - thin-chain segment joining the heavy ends across the view
    /// - perpendicular arrows at each end pointing in the section's view
    ///   direction
    /// - label letter at each arrow (typically capital "A", "B", ...)
    public struct CuttingPlaneLine: Sendable, Hashable {
        public var label: String
        public var traceStart: SIMD2<Double>
        public var traceEnd: SIMD2<Double>
        public var arrowDirection: SIMD2<Double>  // perpendicular to trace, in view 2D
        public var id: String?

        public init(
            label: String,
            traceStart: SIMD2<Double>,
            traceEnd: SIMD2<Double>,
            arrowDirection: SIMD2<Double>,
            id: String? = nil
        ) {
            self.label = label
            self.traceStart = traceStart
            self.traceEnd = traceEnd
            self.arrowDirection = simd_normalize(arrowDirection)
            self.id = id
        }
    }

    /// ISO 128-50 section-view hatching — a closed outer boundary filled with
    /// parallel lines at `angle` radians, spaced `spacing` drawing-units apart.
    ///
    /// Optional `islands` are inner boundaries (holes) that are subtracted
    /// from the hatched region.
    public struct Hatch: Sendable, Hashable {
        public var boundary: [SIMD2<Double>]  // closed polygon (first != last)
        public var angle: Double  // radians; ISO default π/4 = 45°
        public var spacing: Double  // drawing units; ISO typical 2–4 mm
        public var islands: [[SIMD2<Double>]]  // inner holes (each closed polygon)
        public var layer: String  // DXF layer, default "HATCH"
        public var id: String?

        public init(
            boundary: [SIMD2<Double>],
            angle: Double = .pi / 4,
            spacing: Double = 3.0,
            islands: [[SIMD2<Double>]] = [],
            layer: String = "HATCH",
            id: String? = nil
        ) {
            self.boundary = boundary
            self.angle = angle
            self.spacing = spacing
            self.islands = islands
            self.layer = layer
            self.id = id
        }
    }

    /// Assembly-drawing balloon callout: a numbered circle placed near a
    /// part, with an optional leader line to the balloon target.
    ///
    /// Balloon `itemNumber` is expected to match a row in the drawing's
    /// `BillOfMaterials`.
    public struct Balloon: Sendable, Hashable {
        public var itemNumber: Int
        public var centre: SIMD2<Double>
        public var radius: Double
        public var leaderTo: SIMD2<Double>?
        public var id: String?

        public init(
            itemNumber: Int,
            centre: SIMD2<Double>,
            radius: Double = 5,
            leaderTo: SIMD2<Double>? = nil,
            id: String? = nil
        ) {
            self.itemNumber = itemNumber
            self.centre = centre
            self.radius = radius
            self.leaderTo = leaderTo
            self.id = id
        }
    }

    /// A single 2D arc primitive: `centre`/`radius`/`startAngle`/`endAngle` (radians) plus the
    /// DXF/PDF/SVG layer it renders to.
    ///
    /// General-purpose, unlike `centreline`/`centermark`, which always render on a fixed
    /// "CENTER" layer, an arc's layer is caller-supplied (default `"VISIBLE"`, matching
    /// `DrawingPrimitiveSink.addArc`'s own default) — a broken-arc pattern like ISO 6410's
    /// cosmetic-thread end view wants "CENTER", but a general partial-circle annotation might
    /// not. See `DrawingAnnotation.cosmeticThreadEndView(centre:majorDiameter:pitch:)`
    /// (`DrawingThreadAnnotation.swift`) for the ISO 6410 3/4 broken-arc factory built on this
    /// case (#1179: previously a bespoke, non-`DrawingAnnotation` `ArcSegment` type that could
    /// only reach `DXFWriter`, invisible to `Drawing`/PDF/SVG/`bounds()`).
    public struct Arc: Sendable, Hashable {
        public var centre: SIMD2<Double>
        public var radius: Double
        public var startAngle: Double  // radians
        public var endAngle: Double  // radians
        public var layer: String
        public var id: String?

        public init(
            centre: SIMD2<Double>, radius: Double,
            startAngle: Double, endAngle: Double,
            layer: String = "VISIBLE", id: String? = nil
        ) {
            self.centre = centre
            self.radius = radius
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.layer = layer
            self.id = id
        }
    }
}

/// Storage for drawing-level dimensions and annotations.
///
/// Wrapped inside `Drawing` so each Drawing carries its own mutable collection
/// without breaking Sendable.
internal final class DrawingAnnotationStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _dimensions: [DrawingDimension] = []
    private var _annotations: [DrawingAnnotation] = []

    var dimensions: [DrawingDimension] {
        lock.lock()
        defer { lock.unlock() }
        return _dimensions
    }
    var annotations: [DrawingAnnotation] {
        lock.lock()
        defer { lock.unlock() }
        return _annotations
    }

    func appendDimension(_ d: DrawingDimension) {
        lock.lock()
        defer { lock.unlock() }
        _dimensions.append(d)
    }

    func appendAnnotation(_ a: DrawingAnnotation) {
        lock.lock()
        defer { lock.unlock() }
        _annotations.append(a)
    }

    func replaceAnnotations(_ new: [DrawingAnnotation]) {
        lock.lock()
        defer { lock.unlock() }
        _annotations = new
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        _dimensions.removeAll()
        _annotations.removeAll()
    }
}
