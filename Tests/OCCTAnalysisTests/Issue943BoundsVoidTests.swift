import Testing
import simd

@testable import OCCTSwift

/// #943: `bounds`, `size` and `center` became Optional so a shape with no bounding box stops
/// reporting a fabricated `(0,0,0)-(0,0,0)`. The contract these tests pin is that "no box" and
/// "a box that measures zero" are different answers, and that the difference comes from OCCT's own
/// `Bnd_Box::IsVoid()` (reported across the bridge as a `Bool`) rather than from a Swift-side
/// comparison of the six returned doubles against zero.
///
/// Why the value comparison is not merely redundant: `BRepBndLib::AddOptimal`, which backs
/// ``Shape/boundingBoxOptimal(useShapeTolerance:)``, measures a vertex at the world origin as
/// exactly `(0,0,0)-(0,0,0)` (measured, `Scripts/repro/943-bounds-void-vs-zero/`), which is
/// byte-identical to what every failure path writes. All six bounds entry points now share one
/// helper, so the sentinel would be wrong for all of them at once.
@Suite("Issue943 bounds: void versus zero-size")
struct Issue943BoundsVoid {

    /// True when every component of `v` is within `tol` of zero.
    private func isNearZero(_ v: SIMD3<Double>, _ tol: Double = 1e-6) -> Bool {
        abs(v.x) <= tol && abs(v.y) <= tol && abs(v.z) <= tol
    }

    /// A genuinely void shape. `Shape.compound([])` cannot be built (the bridge requires at least
    /// one member), so a far-disjoint intersection is the reachable void fixture, the same one
    /// `BRepBndLibTests` uses.
    private func voidShape() -> Shape? {
        guard let b1 = Shape.box(width: 10, height: 10, depth: 10),
            let b2 = Shape.box(origin: SIMD3(1000, 1000, 1000), width: 10, height: 10, depth: 10)
        else { return nil }
        return b1.intersection(b2)
    }

    @Test func voidShapeHasNoBoundsSizeOrCenter() throws {
        let shape = try #require(voidShape(), "a disjoint intersection should still build a shape")
        #expect(shape.bounds == nil)
        #expect(shape.size == nil)
        #expect(shape.center == nil)
        // The two entry points that already reported this correctly, so the fix converges them
        // rather than moving the divergence (#834).
        #expect(shape.boundingBox == nil)
        #expect(shape.boundingBoxOptimal() == nil)
    }

    /// A point-vertex at the world origin is a real shape whose box measures to zero, or to
    /// within `Precision::Confusion()` of it on the paths that add the shape tolerance. Every
    /// accessor must report that measurement, not `nil`.
    @Test func pointVertexAtOriginReportsAMeasuredBox() throws {
        let origin = try #require(Shape.vertex(at: .zero))

        let bounds = try #require(origin.bounds, "a vertex has a box; only a void shape has none")
        #expect(isNearZero(bounds.min))
        #expect(isNearZero(bounds.max))

        // bounds and boundingBox are the same Bnd_Box through the same helper, so they must agree
        // exactly. This is the #834 divergence pinned shut: before #943 one answered nil for a
        // void shape and the other fabricated zeros.
        let boundingBox = try #require(origin.boundingBox)
        #expect(bounds.min == boundingBox.min)
        #expect(bounds.max == boundingBox.max)

        // The one call in this family that measures a real shape as exactly six zeros, which is
        // why no accessor here may infer "void" from the values.
        let optimal = try #require(origin.boundingBoxOptimal())
        #expect(optimal.min == SIMD3<Double>.zero)
        #expect(optimal.max == SIMD3<Double>.zero)

        // Derived accessors report the measurement too: .zero here is an answer, not a fallback.
        let size = try #require(origin.size)
        let center = try #require(origin.center)
        #expect(isNearZero(size))
        #expect(isNearZero(center))
    }

    /// A zero-length edge at the world origin. `Edge.bounds` had the same defect as
    /// `Shape.bounds` and its own bridge function had no `IsVoid()` check at all. A sphere's polar
    /// degenerate edge is the reachable fixture: it is a genuine edge of a genuine solid whose 3D
    /// extent is a single point, placed at the origin here by translating the sphere.
    @Test func zeroLengthEdgeAtOriginReportsAMeasuredBox() throws {
        // Centred so that its south pole, and therefore that pole's degenerate edge, sits at
        // the world origin.
        let placed = try #require(Shape.sphere(center: SIMD3(0, 0, 5), radius: 5))

        let degenerate = placed.edges().filter { $0.length < 1e-9 }
        #expect(degenerate.count >= 1, "a sphere carries degenerate polar edges")

        let atOrigin = try #require(
            degenerate.first { edge in
                guard let b = edge.bounds else { return false }
                return isNearZero(b.min) && isNearZero(b.max)
            },
            "one polar edge sits at the origin after the translation")

        let bounds = try #require(atOrigin.bounds, "a zero-length edge still has a box")
        #expect(isNearZero(bounds.min))
        #expect(isNearZero(bounds.max))
        #expect(atOrigin.length < 1e-9, "the fixture is the zero-length edge, not a neighbour")
    }

    /// The face pair, and the consumer that force-unwrapped it. `AAG` reads `Face.exactBounds`
    /// for every node it builds; with the accessor Optional, a dropped face would silently change
    /// the node set, so pin that a solid's node count still matches its occurrence count.
    @Test func faceBoundsAreMeasuredAndAAGKeepsEveryFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.faces()
        #expect(faces.count == 6)

        for face in faces {
            #expect(face.bounds != nil)
            #expect(face.exactBounds != nil)
        }

        let aag = box.buildAAG()
        #expect(aag.nodes.count == box.orientedFaces().count)
    }
}
