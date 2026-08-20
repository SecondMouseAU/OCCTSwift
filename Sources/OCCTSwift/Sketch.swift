import Foundation
import simd

// MARK: - Sketch (#72 Phase 4)
//
// A sketch is a collection of 2D curves hosted on a ConstructionPlane, plus a
// `buildProfile` step that filters out construction elements and produces a
// closed `Wire` in 3D (on the host plane).
//
// This is the filter site matching FreeCAD's `SketchObject::buildShape`: the
// solver / editor sees all elements including construction, but `buildProfile`
// excludes construction before any pad / pocket / revolve downstream.
//
// Constraint solving is explicitly out of scope (see #72 non-goals and the
// SwiftGCS private package). Elements carry coordinates; they don't carry
// constraints, and `buildProfile` does not attempt to satisfy any.

public struct SketchElement: Sendable, Hashable {
    public enum CurveKind: Sendable, Hashable {
        case line(from: SIMD2<Double>, to: SIMD2<Double>)
        case arc(center: SIMD2<Double>, radius: Double, startAngle: Double, endAngle: Double)
        case circle(center: SIMD2<Double>, radius: Double)
        case polyline([SIMD2<Double>])

        /// Ordered 2D sample points along this curve. Lines and polylines are exact;
        /// arcs and circles are tessellated using the given `segmentsPerRadian` density.
        public func tessellate2D(segmentsPerRadian: Int = 16) -> [SIMD2<Double>] {
            switch self {
            case .line(let from, let to):
                return [from, to]
            case .polyline(let pts):
                return pts
            case .circle(let center, let radius):
                let segments = max(8, Int(Double(segmentsPerRadian) * 2 * .pi))
                var pts: [SIMD2<Double>] = []
                pts.reserveCapacity(segments + 1)
                for i in 0...segments {
                    let t = Double(i) / Double(segments) * 2 * .pi
                    pts.append(SIMD2(center.x + radius * cos(t),
                                     center.y + radius * sin(t)))
                }
                return pts
            case .arc(let center, let radius, let start, let end):
                let sweep = end - start
                let segments = max(2, Int(Double(segmentsPerRadian) * abs(sweep)))
                var pts: [SIMD2<Double>] = []
                pts.reserveCapacity(segments + 1)
                for i in 0...segments {
                    let t = start + sweep * Double(i) / Double(segments)
                    pts.append(SIMD2(center.x + radius * cos(t),
                                     center.y + radius * sin(t)))
                }
                return pts
            }
        }
    }

    public var curve: CurveKind
    public var isConstruction: Bool
    public var id: UUID

    public init(curve: CurveKind, isConstruction: Bool = false, id: UUID = UUID()) {
        self.curve = curve
        self.isConstruction = isConstruction
        self.id = id
    }
}

public struct Sketch: Sendable, Hashable {
    public var hostPlane: ConstructionContext.PlaneID
    public var elements: [SketchElement]
    public var name: String?

    public init(hostPlane: ConstructionContext.PlaneID,
                elements: [SketchElement] = [],
                name: String? = nil) {
        self.hostPlane = hostPlane
        self.elements = elements
        self.name = name
    }

    public mutating func add(_ element: SketchElement) {
        elements.append(element)
    }

    /// Number of elements excluding construction geometry — i.e. the profile size.
    public var profileElementCount: Int {
        elements.lazy.filter { !$0.isConstruction }.count
    }
}

extension Sketch {
    /// Build a 3D closed profile wire from the sketch's non-construction elements,
    /// placed on the host construction plane.
    ///
    /// Construction elements are filtered out at this single site — upstream uses
    /// of the sketch (solver, constraint editor, agent-facing accessors) see the
    /// full element set including construction.
    ///
    /// - Parameters:
    ///   - context: The construction context that registered `hostPlane`.
    ///   - graph: A BRepGraph against which to resolve the host plane's recipe.
    /// - Returns: A closed Wire on the resolved plane, or nil if the host plane
    ///   fails to resolve or no profile elements exist.
    public func buildProfile(in context: ConstructionContext,
                             graph: BRepGraph) -> Wire? {
        let profileElements = elements.filter { !$0.isConstruction }
        guard !profileElements.isEmpty else { return nil }

        let placement: Placement
        switch context.resolve(hostPlane, in: graph) {
        case .success(let p): placement = p
        case .failure: return nil
        }

        // Lift 2D elements into 3D using the placement's frame, then assemble a wire.
        var points3D: [SIMD3<Double>] = []
        for element in profileElements {
            let elementPoints = element.curve.tessellate2D(segmentsPerRadian: 16)
            for (i, pt) in elementPoints.enumerated() {
                let p = placement.lift(pt)
                if i == 0 && !points3D.isEmpty && approxEqual(points3D.last!, p) { continue }
                points3D.append(p)
            }
        }

        guard points3D.count >= 2 else { return nil }
        // Close the wire if not already closed.
        let closed = approxEqual(points3D.first!, points3D.last!)
        return Wire.polygon3D(points3D, closed: closed)
    }

    private func approxEqual(_ a: SIMD3<Double>, _ b: SIMD3<Double>, tolerance: Double = 1e-9) -> Bool {
        simd_length_squared(a - b) < tolerance * tolerance
    }
}
