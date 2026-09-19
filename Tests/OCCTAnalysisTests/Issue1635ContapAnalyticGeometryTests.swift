import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1635: an analytic silhouette had no reachable geometry.
///
/// `ContapContourResult.pointCount/point/points` are `Contap_Line::NbPnts()`/`Point(Index)`, which
/// both open with `if (typL != Contap_Walking) { throw Standard_DomainError(); }`. So a cylinder's
/// tangent rulings and a sphere's silhouette circle, which is what `contapContourDirection(_:)`
/// produces most of the time, reported no points at all, and the geometry OCCT does hold for them
/// (`Line()`, `Circle()`, `Arc()`, `NbVertex()`/`Vertex()`) was not wrapped.
///
/// Ground truth for every figure below is `Scripts/repro/1635-contap-analytic-geometry/probe.mm`.
@Suite("Issue 1635: an analytic contour carries its geometry")
struct Issue1635ContapAnalyticGeometryTests {

    /// The face of `shape` whose contour along `direction` has `wanted` as its first line type,
    /// with that contour. Contap reports nothing for a face that is not on the silhouette, so the
    /// caller cannot know the face index in advance.
    private func contour(
        of shape: Shape, along direction: SIMD3<Double>, firstLineType wanted: ContourLineType
    ) -> ContapContourResult? {
        for face in shape.subShapes(ofType: .face) {
            guard let c = face.contapContourDirection(direction), c.lineCount > 0 else { continue }
            if c.lineType(1) == wanted { return c }
        }
        return nil
    }

    /// The case the issue names. A cylinder of radius 5 along +Z, viewed along +X: two tangent
    /// rulings at y = +5 and y = -5, each running the height of the face.
    @Test func cylinderRulingsHaveGeometry() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let contour = contour(of: cyl, along: SIMD3(1, 0, 0), firstLineType: .line)
        else {
            Issue.record("no .line contour on the cylinder's lateral face")
            return
        }

        #expect(contour.lineCount == 2)

        var yOrigins: [Double] = []
        for line in 1...contour.lineCount {
            #expect(contour.lineType(line) == .line)

            // Unchanged, and the reason this issue exists: the traced accessors refuse.
            #expect(contour.pointCount(line: line) == 0)
            #expect(contour.points(line: line).isEmpty)

            guard case let .line(origin, direction)? = contour.geometry(line: line) else {
                Issue.record("line \(line) has no .line geometry")
                continue
            }
            // The ruling runs along the cylinder's axis, and touches it nowhere: it is offset by
            // the full radius in y, on the axis-perpendicular side facing the viewer.
            #expect(abs(origin.x) < 1e-9)
            #expect(abs(abs(origin.y) - 5.0) < 1e-9)
            #expect(abs(abs(direction.z) - 1.0) < 1e-9)
            #expect(abs(direction.x) < 1e-9)
            #expect(abs(direction.y) < 1e-9)
            yOrigins.append(origin.y)

            // NbVertex() is valid on every type, and these are the ruling's two ends.
            let vertices = contour.vertices(line: line)
            #expect(contour.vertexCount(line: line) == 2)
            #expect(vertices.count == 2)
            let zs = vertices.map(\.point.z).sorted()
            if zs.count == 2 {
                #expect(abs(zs[0]) < 1e-9)
                #expect(abs(zs[1] - 20.0) < 1e-9)
            }
            for v in vertices {
                #expect(abs(abs(v.point.y) - 5.0) < 1e-9)
                // Each end sits on the face's own boundary circle, so it has an arc parameter.
                // `nil` is how ContourVertex spells IsOnArc() == false, since ParameterOnArc()
                // throws there and 0 is a valid parameter.
                #expect(v.parameterOnArc != nil)
            }
        }
        // One ruling either side of the axis, not two on the same side.
        #expect(yOrigins.count == 2)
        if yOrigins.count == 2 { #expect(yOrigins[0] * yOrigins[1] < 0) }
    }

    /// A sphere of radius 7 viewed along +Z: one great circle, of the sphere's own radius, about
    /// the view direction.
    @Test func sphereSilhouetteIsAGreatCircle() {
        guard let sph = Shape.sphere(radius: 7),
            let contour = contour(of: sph, along: SIMD3(0, 0, 1), firstLineType: .circle)
        else {
            Issue.record("no .circle contour on the sphere")
            return
        }

        #expect(contour.pointCount(line: 1) == 0)
        guard case let .circle(center, axis, xDirection, radius)? = contour.geometry(line: 1) else {
            Issue.record("line 1 has no .circle geometry")
            return
        }
        #expect(abs(radius - 7.0) < 1e-9)
        #expect(abs(center.x) < 1e-9)
        #expect(abs(center.y) < 1e-9)
        #expect(abs(center.z) < 1e-9)
        // A silhouette circle is perpendicular to the view direction, so its axis is that
        // direction, and its X direction is perpendicular to it.
        #expect(abs(abs(axis.z) - 1.0) < 1e-9)
        #expect(abs(simd_dot(axis, xDirection)) < 1e-9)
        #expect(abs(simd_length(xDirection) - 1.0) < 1e-9)
    }

    /// A traced contour still reports its points, and reports the same ones through the new door.
    @Test func walkingContourAgreesWithThePointAccessors() {
        guard let tor = Shape.torus(majorRadius: 10, minorRadius: 3),
            let contour = contour(of: tor, along: SIMD3(1, 0, 0), firstLineType: .walking)
        else {
            Issue.record("no .walking contour on the torus")
            return
        }

        let direct = contour.points(line: 1)
        #expect(direct.count > 2, "a traced contour has real points")
        guard case let .walking(points)? = contour.geometry(line: 1) else {
            Issue.record("line 1 has no .walking geometry")
            return
        }
        #expect(points.count == direct.count)
        for (a, b) in zip(points, direct) { #expect(simd_distance(a, b) < 1e-12) }

        // Vertices are the ends of the traced run, and exist here too.
        #expect(contour.vertexCount(line: 1) >= 2)
    }

    /// A planar face viewed edge on: the whole boundary is on the silhouette, which is where a
    /// `.restriction` contour comes from. Its geometry is the boundary arc's parameter range, and
    /// the arc evaluates to the vertices at its ends.
    @Test func restrictionContourHasAnArc() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let contour = contour(of: box, along: SIMD3(1, 0, 0), firstLineType: .restriction)
        else {
            Issue.record("no .restriction contour on the box")
            return
        }

        #expect(contour.pointCount(line: 1) == 0)
        guard case let .restriction(range)? = contour.geometry(line: 1) else {
            Issue.record("line 1 has no .restriction geometry")
            return
        }
        // One edge of a 10-unit face, parameterised by arc length.
        #expect(abs((range.upperBound - range.lowerBound) - 10.0) < 1e-9)

        // The arc's ends are the line's two vertices, in the face's UV space. Two new accessors
        // agreeing with each other, rather than one asserted against a constant.
        let vertices = contour.vertices(line: 1)
        #expect(vertices.count == 2)
        let first = contour.arcPoint(line: 1, parameter: range.lowerBound)
        let last = contour.arcPoint(line: 1, parameter: range.upperBound)
        #expect(first != nil)
        #expect(last != nil)
        if let first, let last, vertices.count == 2 {
            let ends = [first, last]
            for v in vertices {
                #expect(ends.contains { simd_distance($0, v.uv) < 1e-9 })
            }
        }
    }

    /// Each accessor refuses a line of the wrong type, and refuses it as `nil` rather than as a
    /// zero. `Contap_Line` refuses it too, by throwing.
    @Test func accessorsRefuseTheWrongLineType() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let lines = contour(of: cyl, along: SIMD3(1, 0, 0), firstLineType: .line)
        else {
            Issue.record("no .line contour on the cylinder's lateral face")
            return
        }
        // A .line contour is not a restriction, so the arc accessors have nothing to answer.
        #expect(lines.arcRange(line: 1) == nil)
        #expect(lines.arcPoint(line: 1, parameter: 0) == nil)

        // Out-of-range line indices, on every new accessor.
        #expect(lines.geometry(line: 0) == nil)
        #expect(lines.geometry(line: lines.lineCount + 1) == nil)
        #expect(lines.vertexCount(line: 0) == 0)
        #expect(lines.vertexCount(line: lines.lineCount + 1) == 0)
        #expect(lines.vertex(line: 1, index: 0) == nil)
        #expect(lines.vertex(line: 1, index: lines.vertexCount(line: 1) + 1) == nil)

        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let restriction = contour(of: box, along: SIMD3(1, 0, 0), firstLineType: .restriction)
        else {
            Issue.record("no .restriction contour on the box")
            return
        }
        // A .restriction contour is not a line or a circle, and geometry(line:) says so by
        // returning the case that does apply rather than nil.
        if case .restriction = restriction.geometry(line: 1) {} else {
            Issue.record("expected .restriction geometry")
        }
    }
}
