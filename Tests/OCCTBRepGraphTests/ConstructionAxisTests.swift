import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.142 ConstructionAxis resolution")
struct ConstructionAxisTests {
    typealias Axis = (origin: SIMD3<Double>, direction: SIMD3<Double>)
    typealias AxisResult = Result<Axis, ConstructionResolutionError>

    private static let zAxis = SIMD3<Double>(0, 0, 1)

    // MARK: - Helpers

    /// Finds the index of the first edge in `graph` whose curve type is `curveType`, or nil if
    /// none exists.
    ///
    /// Shared by the two "straight seam reparameterized as a BSpline" fixtures below (cylinder
    /// and cone), which each searched for the synthetic BSpline seam edge with a byte-identical
    /// inline loop (#1252).
    private func firstEdgeIndex(in graph: BRepGraph, curveType: Edge.CurveType) -> Int? {
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first
            else { continue }
            if edge.curveType == curveType {
                return edgeIndex
            }
        }
        return nil
    }

    private func alongEdge(_ graph: BRepGraph, _ edgeIndex: Int) -> AxisResult {
        graph.resolve(ConstructionAxis.alongEdge(.literal(.init(kind: .edge, index: edgeIndex))))
    }

    private func normalToFace(_ graph: BRepGraph, face: Int, vertex: Int) -> AxisResult {
        graph.resolve(
            ConstructionAxis.normalToFace(
                face: .literal(.init(kind: .face, index: face)),
                at: .literal(.init(kind: .vertex, index: vertex))))
    }

    /// The message of a `.degenerate` failure, or nil for any other outcome.
    private func degenerateMessage(_ result: AxisResult) -> String? {
        if case .failure(.degenerate(let message)) = result { return message }
        return nil
    }

    private func isClose(
        _ a: SIMD3<Double>, _ b: SIMD3<Double>, _ tolerance: Double = 1e-9
    ) -> Bool {
        simd_distance(a, b) < tolerance
    }

    private struct CircleEdge {
        let index: Int
        let edge: Edge
        let start: SIMD3<Double>
    }

    /// Every edge of `graph` whose curve is a circle, with the point it starts at.
    private func circleEdges(in graph: BRepGraph) -> [CircleEdge] {
        var found: [CircleEdge] = []
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first, edge.curveType == .circle,
                let bounds = edge.parameterBounds, let start = edge.point(at: bounds.first)
            else { continue }
            found.append(CircleEdge(index: edgeIndex, edge: edge, start: start))
        }
        return found
    }

    /// The kinds of axis-bearing surface among the faces adjacent to an edge (planes have none).
    private func adjacentSurfaceKinds(_ graph: BRepGraph, _ edgeIndex: Int) -> [ShapeAxis.Kind] {
        graph.faces(of: edgeIndex).compactMap { faceIndex in
            graph.shape(nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex)?.faces().first?
                .primaryAxis?.kind
        }
    }

    /// The first face of `graph` whose surface reports an axis of the given kind.
    private func faceIndex(in graph: BRepGraph, withAxisKind kind: ShapeAxis.Kind) -> Int? {
        for faceIndex in 0..<graph.faceCount {
            let shape = graph.shape(nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex)
            if shape?.faces().first?.primaryAxis?.kind == kind {
                return faceIndex
            }
        }
        return nil
    }

    /// The way `axis` must point for `edge`, followed from its first parameter, to turn
    /// counterclockwise around it by the right-hand rule.
    ///
    /// Found from two points a quarter of the parameter span apart and a point `center` on the
    /// axis line, with no tangent involved, so it is a second construction of the sign
    /// `resolveEdgeDirection` derives from `Edge.tangent(at:)`.
    private func rightHandedAxis(
        of edge: Edge, about axis: SIMD3<Double>, through center: SIMD3<Double>
    ) throws -> SIMD3<Double> {
        let bounds = try #require(edge.parameterBounds, "edge bounds")
        let first = try #require(edge.point(at: bounds.first), "first point of the edge")
        let span = bounds.last - bounds.first
        let ahead = try #require(edge.point(at: bounds.first + span * 0.25), "a quarter ahead")
        let turn = simd_dot(axis, simd_cross(first - center, ahead - center))
        try #require(abs(turn) > 1e-12, "the two samples must not be collinear with the axis")
        return turn > 0 ? axis : -axis
    }

    // MARK: - alongEdge

    @Test("alongEdge produces edge start + unit direction")
    func alongEdge() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        #expect(graph.edgeCount == 12)
        // Shape.box is centred on the origin, so every corner has all three coordinates at +-5
        // and every edge is axis-aligned and 10 long: both facts come from the box, not from the
        // resolver. An edge's axis starts at its start and runs to its end.
        func isCorner(_ p: SIMD3<Double>) -> Bool {
            [p.x, p.y, p.z].allSatisfy { abs(abs($0) - 5.0) < 1e-9 }
        }
        for edgeIndex in 0..<graph.edgeCount {
            let edgeShape = try #require(
                graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                "shape of edge \(edgeIndex)")
            let edge = try #require(edgeShape.edges().first, "edge \(edgeIndex)")
            let bounds = try #require(edge.parameterBounds, "bounds of edge \(edgeIndex)")
            let start = try #require(edge.point(at: bounds.first), "start of edge \(edgeIndex)")
            let end = try #require(edge.point(at: bounds.last), "end of edge \(edgeIndex)")
            #expect(isCorner(start) && isCorner(end), "edge \(edgeIndex): \(start) to \(end)")

            let ax = try alongEdge(graph, edgeIndex).get()
            #expect(
                isClose(ax.origin, start), "edge \(edgeIndex): origin \(ax.origin), start \(start)")
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-12, "edge \(edgeIndex): not unit")
            let reach = ax.origin + 10.0 * ax.direction
            #expect(isClose(reach, end), "edge \(edgeIndex): start + 10 * direction is \(reach)")
        }
    }

    @Test("alongEdge on a full-circle cylindrical rim resolves to the true rotation axis (#883)")
    func alongEdgeCylindricalRimUsesRevolutionAxis() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10), "cylinder")
        let graph = try #require(BRepGraph(shape: cyl), "graph of the cylinder")
        // A rim is a full circle: start == end, so the old secant-of-endpoints computation
        // was always the zero vector here, this is failure mode 1 from #883.
        let rims = circleEdges(in: graph)
        #expect(rims.count == 2, "a cylinder has a top rim and a bottom rim")
        var heights: [Double] = []
        for rim in rims {
            #expect(rim.edge.isClosed3D, "a rim is a closed circle")
            #expect(
                adjacentSurfaceKinds(graph, rim.index).contains(.cylinder), "rim bounds the wall")
            let rimHeight = rim.start.z
            // The axis runs the way the rim turns, by the right-hand rule. Both rims run
            // counterclockwise seen from +Z, so that is +Z.
            let onAxis = SIMD3<Double>(0, 0, rimHeight)
            let expected = try rightHandedAxis(of: rim.edge, about: Self.zAxis, through: onAxis)
            #expect(isClose(expected, Self.zAxis), "fixture: the rim turns counterclockwise")

            let ax = try alongEdge(graph, rim.index).get()
            #expect(
                isClose(ax.direction, expected), "rim at z \(rimHeight): direction \(ax.direction)")
            // #894 finding 2: the origin must stay edge-local (on the axis, at the rim's own
            // height), not teleport to the cylinder surface's own placement origin, which would
            // report (0, 0, 0) regardless of which rim (top or bottom) this is.
            #expect(isClose(ax.origin, onAxis), "rim at z \(rimHeight): origin \(ax.origin)")
            heights.append(rimHeight)
        }
        heights.sort()
        try #require(heights.count == 2)
        #expect(abs(heights[0]) < 1e-9, "rims at \(heights)")
        #expect(abs(heights[1] - 10.0) < 1e-9, "rims at \(heights)")
    }

    @Test(
        "alongEdge on a partial cylindrical arc resolves to the axis, not the endpoint chord (#883)"
    )
    func alongEdgePartialCylinderUsesAxisNotChord() throws {
        let cyl = try #require(
            Shape.cylinder(radius: 5, height: 10, angle: .pi / 2), "partial cylinder")
        let graph = try #require(BRepGraph(shape: cyl), "graph of the partial cylinder")
        let arcs = circleEdges(in: graph).filter { !$0.edge.isClosed3D }
        #expect(arcs.count == 2, "a quarter cylinder has a top arc and a bottom arc")
        for arc in arcs {
            // A 90-degree arc's own endpoint chord lies in the XY plane (z ~ 0), this is failure
            // mode 2 from #883: a plausible-looking but wrong direction. The true rotation axis
            // is parallel to Z, and perpendicular to that chord.
            let bounds = try #require(arc.edge.parameterBounds, "arc bounds")
            let end = try #require(arc.edge.point(at: bounds.last), "arc end")
            let chordDirection = simd_normalize(end - arc.start)
            let onAxis = SIMD3<Double>(0, 0, arc.start.z)
            let expected = try rightHandedAxis(of: arc.edge, about: Self.zAxis, through: onAxis)
            #expect(isClose(expected, Self.zAxis), "fixture: the arc turns counterclockwise")

            let ax = try alongEdge(graph, arc.index).get()
            #expect(isClose(ax.direction, expected), "arc at z \(arc.start.z): \(ax.direction)")
            #expect(
                abs(simd_dot(ax.direction, chordDirection)) < 1e-9, "the chord is not the answer")
            // #894 finding 2: the origin must stay edge-local (on the axis, at the arc's own
            // height), not the surface's own placement origin (0, 0, 0) regardless of which end
            // of the cylinder this arc sits at.
            #expect(isClose(ax.origin, onAxis), "arc at z \(arc.start.z): origin \(ax.origin)")
        }
    }

    @Test(
        "alongEdge on a standalone closed circular wire (no adjacent face) fails with degenerate (#887)"
    )
    func alongEdgeStandaloneCircleNoAdjacentFaceDegenerate() throws {
        // A full circle with no adjacent face at all: revolutionAxis(ofEdgeAt:) finds nothing
        // to redirect to (faces(of:) is empty), so this falls through to the endpoint-secant
        // path, where start == end for a closed curve, the zero-length branch that #887 found
        // had no coverage at all.
        let wire = try #require(Wire.circle(radius: 5), "circle wire")
        let wireShape = try #require(Shape.fromWire(wire), "wire shape")
        let graph = try #require(BRepGraph(shape: wireShape), "graph of the wire")
        let edge = try #require(wireShape.edges().first, "edge of the wire")
        let edgeShape = try #require(Shape.fromEdge(edge), "edge shape")
        let node = try #require(graph.findNode(for: edgeShape), "edge node")
        try #require(node.kind == .edge, "the node is an edge")
        #expect(graph.faces(of: node.index).isEmpty)
        let closed = alongEdge(graph, node.index)
        #expect(degenerateMessage(closed) != nil, "a closed circle's secant is zero: \(closed)")

        // The control, the same situation but open: a curved edge with no face to redirect to
        // falls back to its own chord, from where it starts to where it ends. So the failure
        // above is the closure, not "no adjacent face".
        let mid = SIMD3<Double>(5 * cos(Double.pi / 4), 5 * sin(Double.pi / 4), 0)
        let arcCurve = try #require(
            Curve3D.arcOfCircle(start: SIMD3(5, 0, 0), interior: mid, end: SIMD3(0, 5, 0)),
            "quarter arc curve")
        let arcShape = try #require(Shape.edgeFromCurve(arcCurve), "quarter arc edge")
        let arcGraph = try #require(BRepGraph(shape: arcShape), "graph of the arc")
        #expect(arcGraph.edgeCount == 1)
        #expect(arcGraph.faces(of: 0).isEmpty)
        let ax = try alongEdge(arcGraph, 0).get()
        #expect(isClose(ax.origin, SIMD3<Double>(5, 0, 0)), "arc origin \(ax.origin)")
        let chord = simd_normalize(SIMD3<Double>(-5, 5, 0))
        #expect(isClose(ax.direction, chord), "arc direction \(ax.direction)")
    }

    @Test(
        "alongEdge on a T-branch between two non-coaxial cylinders falls back to the chord, not whichever face's axis sorts first (#894 finding 1)"
    )
    func alongEdgeBranchWithDisagreeingAxesFallsBackToChord() throws {
        // Two non-coaxial cylinders fused at a T-junction: the intersection curve is adjacent to
        // both cylindrical walls, and the two candidate axes do not agree, exactly the branch
        // case finding 1 covers. Pre-fix, `revolutionAxis(ofEdgeAt:)` returned whichever face's
        // axis happened to sort first in `faces(of:)`, with no check that a second, disagreeing
        // candidate existed.
        let mainCyl = try #require(
            Shape.cylinder(
                at: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1), radius: 5, height: 20),
            "main cylinder")
        let branchCyl = try #require(
            Shape.cylinder(
                at: SIMD3(-10, -10, -2), direction: simd_normalize(SIMD3(1, 1, 0.3)),
                radius: 2.5, height: 20),
            "branch cylinder")
        let fused = try #require(mainCyl.union(branchCyl), "fused T-branch")
        let graph = try #require(BRepGraph(shape: fused), "graph of the T-branch")

        // Find a branch edge: adjacent to >= 2 cylindrical/conical faces whose axes disagree, with
        // a non-degenerate chord that also isn't itself nearly parallel to EITHER candidate axis,
        // so the pre-fix "first match wins" answer and the post-fix chord-fallback answer are
        // provably different regardless of which face BRepGraph happens to enumerate first.
        //
        // Gathering `candidates` here (via the already-public `faces(of:)`/`Face.primaryAxis`) is
        // direct data access, not a reimplementation of production logic, there's no production
        // API that returns the raw candidate list, only the final decision. What used to be
        // reimplemented was the "must disagree" *test*, via a hand-rolled, hardcoded `1e-3` copy
        // of `axesAgree`'s own comparison; that copy is gone below, replaced by a direct call to
        // the real (`internal`, `@testable`-visible) `axesAgree` (#894 finding 5, second pass).
        var target: (edgeIndex: Int, start: SIMD3<Double>, end: SIMD3<Double>)?
        for edgeIndex in 0..<graph.edgeCount {
            var candidates: [ShapeAxis] = []
            for faceIndex in graph.faces(of: edgeIndex) {
                guard
                    let faceShape = graph.shape(
                        nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                    let face = faceShape.faces().first,
                    let axis = face.primaryAxis,
                    axis.kind == .cylinder || axis.kind == .cone
                else { continue }
                candidates.append(axis)
            }
            guard candidates.count >= 2, !graph.axesAgree(candidates[0], candidates[1]) else {
                continue
            }

            guard
                let edgeShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = edgeShape.edges().first,
                let bounds = edge.parameterBounds,
                let start = edge.point(at: bounds.first),
                let end = edge.point(at: bounds.last)
            else { continue }
            let chord = end - start
            let chordLength = simd_length(chord)
            guard chordLength > 1e-6 else { continue }
            let chordDirection = chord / chordLength
            let directionA = simd_normalize(candidates[0].direction)
            let directionB = simd_normalize(candidates[1].direction)
            guard abs(simd_dot(chordDirection, directionA)) < 0.9,
                abs(simd_dot(chordDirection, directionB)) < 0.9
            else { continue }

            target = (edgeIndex, start, end)
            break
        }
        let branch = try #require(target, "no usable branch edge found in T-branch fixture")

        // Exercise the real production decision directly, not just its downstream effect: the
        // disagreeing candidates found above must make `revolutionAxis(ofEdgeAt:)` itself decline
        // (#894 finding 5, second pass), the assertions below on `resolve(.alongEdge(...))` then
        // confirm the caller-visible consequence of that decision.
        #expect(graph.revolutionAxis(ofEdgeAt: branch.edgeIndex) == nil)

        // The fallback is the edge's own chord, exactly: it starts where the edge starts and runs
        // to where it ends. That is not either candidate face's axis (the pre-fix bug), which the
        // search above guaranteed is more than 0.9 off the chord in dot product.
        let ax = try alongEdge(graph, branch.edgeIndex).get()
        #expect(isClose(ax.origin, branch.start), "origin \(ax.origin), edge start \(branch.start)")
        let chord = simd_normalize(branch.end - branch.start)
        #expect(isClose(ax.direction, chord), "direction \(ax.direction), chord \(chord)")
    }

    @Test(
        "alongEdge keeps the origin edge-local, not the adjacent surface's own placement origin (#894 finding 2)"
    )
    func alongEdgeCylindricalRimOriginStaysNearRimNotSurfaceBase() throws {
        // A rim near the TOP of a tall cylinder whose base sits at z=0, the review's own example
        // of a ~500mm teleport. axis.origin for the wall face is the surface's own placement
        // origin (0, 0, 0); if that leaked through as the resolved origin, a materialized axis
        // marker or a sketch plane built `throughAxis` would land ~500mm from the rim the caller
        // actually selected.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 500), "tall cylinder")
        let graph = try #require(BRepGraph(shape: cyl), "graph of the tall cylinder")
        let rims = circleEdges(in: graph)
        let topRim = try #require(
            rims.first(where: { abs($0.start.z - 500.0) < 1e-6 }), "the rim at z = 500")
        let bottomRim = try #require(
            rims.first(where: { abs($0.start.z) < 1e-6 }), "the rim at z = 0")
        for rim in [topRim, bottomRim] {
            let onAxis = SIMD3<Double>(0, 0, rim.start.z)
            let expected = try rightHandedAxis(of: rim.edge, about: Self.zAxis, through: onAxis)
            let ax = try alongEdge(graph, rim.index).get()
            // On the axis at the rim's own height: (0, 0, 500) for the top and (0, 0, 0) for
            // the bottom, so the surface's origin is right for one and a teleport for the other.
            #expect(isClose(ax.origin, onAxis), "rim at z \(rim.start.z): origin \(ax.origin)")
            #expect(isClose(ax.direction, expected), "rim at z \(rim.start.z): \(ax.direction)")
        }
    }

    @Test(
        "alongEdge on a geometrically-straight seam reparameterized as a BSpline keeps the chord, not the axis (#894 finding 3)"
    )
    func alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord() throws {
        // curveType is a proxy for straightness, not proof of it: OCCT commonly represents a
        // geometrically-straight edge as a low-degree BSpline after a Boolean/fillet/sweep. Build
        // that shape directly rather than hunting for a specific real operation that happens to
        // trigger it: a "seam" edge on a cylindrical wall whose 3D curve is a BSpline interpolated
        // through 3 exactly-collinear points (so curveType != .line) but is still, geometrically,
        // the straight generatrix line at that angle.
        let radius = 5.0
        let angle0 = 0.0
        let angle1 = 0.3
        let p0bot = SIMD3(radius * cos(angle0), radius * sin(angle0), 0.0)
        let p0mid = SIMD3(radius * cos(angle0), radius * sin(angle0), 5.0)
        let p0top = SIMD3(radius * cos(angle0), radius * sin(angle0), 10.0)
        let p1bot = SIMD3(radius * cos(angle1), radius * sin(angle1), 0.0)
        let p1top = SIMD3(radius * cos(angle1), radius * sin(angle1), 10.0)
        let midAngle = (angle0 + angle1) / 2

        let surface = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius), "surface")
        let seamCurve = try #require(
            Curve3D.interpolate(points: [p0bot, p0mid, p0top]), "seam curve")
        let seamEdgeShape = try #require(Shape.edgeFromCurve(seamCurve), "seam edge shape")
        let seamEdge = try #require(Edge(seamEdgeShape), "seam edge")
        let otherSideWire = try #require(Wire.line(from: p1top, to: p1bot), "other side wire")
        let otherSideEdge = try #require(otherSideWire.edges().first, "other side edge")
        let topArcCurve = try #require(
            Curve3D.arcOfCircle(
                start: p0top,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 10.0),
                end: p1top),
            "top arc curve")
        let topArcShape = try #require(Shape.edgeFromCurve(topArcCurve), "top arc shape")
        let topArcEdge = try #require(Edge(topArcShape), "top arc edge")
        let botArcCurve = try #require(
            Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0),
                end: p0bot),
            "bottom arc curve")
        let botArcShape = try #require(Shape.edgeFromCurve(botArcCurve), "bottom arc shape")
        let botArcEdge = try #require(Edge(botArcShape), "bottom arc edge")
        let wire = try #require(
            Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]), "wire")
        let faceShape = try #require(Shape.face(from: surface, boundary: wire), "face")
        let graph = try #require(BRepGraph(shape: faceShape), "graph of the face")

        // Confirm the fixture matches the intended scenario, then find that edge by its (unique)
        // BSpline curveType rather than assuming an index.
        let seamNodeIndex = try #require(
            firstEdgeIndex(in: graph, curveType: .bsplineCurve), "no BSpline-curveType edge found")
        #expect(
            adjacentSurfaceKinds(graph, seamNodeIndex).contains(.cylinder), "seam bounds the wall")

        let ax = try alongEdge(graph, seamNodeIndex).get()
        // The seam runs up the generatrix (interpolated bottom to top), so the chord runs along
        // +Z. The direction is +Z either way, since axis and chord happen to agree here. The
        // origin is what distinguishes "kept the chord" from "redirected to the axis":
        // redirecting would project onto the cylinder's own axis line (x=y=0), which for this
        // seam happens to yield (0, 0, 0) too, so the discriminating check is that the origin
        // stays at the edge's own start, on the wall, not on the centerline.
        #expect(isClose(ax.direction, Self.zAxis), "direction \(ax.direction)")
        #expect(isClose(ax.origin, p0bot), "origin \(ax.origin), the seam starts at \(p0bot)")
    }

    /// A cylinder (radius 5, height 20) intersected with a large box tilted about Y by `theta`.
    ///
    /// The box's top face passes through (0, 0, 10), the cylinder's own mid-height on its axis,
    /// with normal (sin theta, 0, cos theta). At `theta` = 0 that is the plane z = 10, a
    /// perpendicular cross-section whose rim is a circle; otherwise the rim is an ellipse.
    private func obliqueCut(theta: Double) throws -> (cut: Shape, graph: BRepGraph) {
        let radius = 5.0
        let height = 20.0
        // Box spans z in [-1000, z0] before rotation; z0 is chosen so the rotated top face
        // passes through (0, 0, 10).
        let z0 = 10.0 * cos(theta)
        let cyl = try #require(Shape.cylinder(radius: radius, height: height), "cylinder")
        let bigBox = try #require(
            Shape.box(
                origin: SIMD3(-500, -500, -1000), width: 1000, height: 1000, depth: 1000 + z0),
            "big box")
        let tiltedBox = try #require(
            bigBox.rotated(axis: SIMD3(0, 1, 0), angle: theta), "tilted box")
        let cut = try #require(cyl.intersection(tiltedBox), "oblique cut")
        let graph = try #require(BRepGraph(shape: cut), "graph of the oblique cut")
        return (cut, graph)
    }

    @Test(
        "alongEdge on an elliptical rim from an oblique cylinder cut does not silently return the cylinder's centerline (#894 finding 1, third pass)"
    )
    func alongEdgeEllipticalRimDoesNotSilentlyReturnCenterline() throws {
        // A cylinder intersected with a large box tilted about Y by 25 degrees: the box's near
        // face becomes an oblique cutting plane through the cylinder's mid-height, producing a
        // closed elliptical rim (curveType == .ellipse) adjacent to the cylindrical wall. Every
        // point of that rim sits on the wall (radius == cylinder radius everywhere, same as a
        // true circular rim), but its height along the axis varies as you go around it, exactly
        // the case `curveType != .line` alone can't distinguish from a genuine cross-section.
        let (cut, graph) = try obliqueCut(theta: 25.0 * Double.pi / 180)
        let ellipse = try #require(
            cut.edges().first(where: { $0.curveType == .ellipse }), "elliptical rim edge")
        let ellipseShape = try #require(Shape.fromEdge(ellipse), "elliptical rim shape")
        let node = try #require(graph.findNode(for: ellipseShape), "elliptical rim node")
        try #require(node.kind == .edge, "the node is an edge")
        // Confirm the fixture matches finding 1's premise: exactly one adjacent face contributes
        // a cylinder/cone axis candidate (the trimmed wall), same as a genuine circular rim, so
        // `revolutionAxis` has nothing to disagree with and would return it unconditionally
        // without the geometric cross-section check this finding adds.
        let candidates = adjacentSurfaceKinds(graph, node.index).filter {
            $0 == .cylinder || $0 == .cone
        }
        #expect(candidates.count == 1)
        // And the rim is closed, so the chord that is all that remains once the axis redirect is
        // declined has no length.
        let bounds = try #require(ellipse.parameterBounds, "ellipse bounds")
        let start = try #require(ellipse.point(at: bounds.first), "ellipse start")
        let end = try #require(ellipse.point(at: bounds.last), "ellipse end")
        #expect(simd_distance(start, end) < 1e-9, "a full ellipse closes on itself")

        // The answer is a clean `.degenerate`: not the cylinder's centerline (the bug), and not
        // some other made-up axis either. A full ellipse's own chord is zero, same as a full
        // circle's would be without the (correctly declined) axis redirect.
        let result = alongEdge(graph, node.index)
        #expect(degenerateMessage(result) != nil, "expected .degenerate, got \(result)")

        // The control, built the same way with the cutting plane perpendicular to the axis: a
        // genuine circular cross-section DOES resolve to the centerline, at the rim's height.
        let (_, flatGraph) = try obliqueCut(theta: 0)
        let rim = try #require(
            circleEdges(in: flatGraph).first(where: { abs($0.start.z - 10.0) < 1e-9 }),
            "the circular cut rim at z = 10")
        let onAxis = SIMD3<Double>(0, 0, 10)
        let expected = try rightHandedAxis(of: rim.edge, about: Self.zAxis, through: onAxis)
        let ax = try alongEdge(flatGraph, rim.index).get()
        #expect(isClose(ax.direction, expected), "circular rim direction \(ax.direction)")
        #expect(isClose(ax.origin, onAxis), "circular rim origin \(ax.origin)")
    }

    @Test(
        "alongEdge on a genuinely near-zero-length edge next to a clean cylindrical face still reports degenerate (#894 finding 2, third pass)"
    )
    func alongEdgeGenuinelyDegenerateEdgeNextToCleanCylinderStillDegenerate() throws {
        // A partial cylinder with an astronomically tiny angular extent (1e-10 rad): its two rim
        // arcs (curveType == .circle, non-linear, so the OLD `curveType != .line` gate alone
        // would have let this reach `revolutionAxis`) measure a true length of 5e-10, genuinely
        // near-zero and below this file's degeneracy epsilon, while still bounding one clean
        // cylindrical wall face, the shape finding 2 needs: `revolutionAxis` finds an
        // unambiguous candidate axis for an edge that is itself malformed, which used to let it
        // skip the degeneracy check entirely.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10, angle: 1e-10), "sliver")
        let graph = try #require(BRepGraph(shape: cyl), "graph of the sliver")
        let slivers = circleEdges(in: graph).filter { $0.edge.length < 1e-9 }
        #expect(slivers.count == 2, "the top and the bottom arc are both slivers")
        for sliver in slivers {
            // Confirm the fixture matches finding 2's premise: exactly one adjacent face
            // contributes a cylinder/cone axis candidate, same as a legitimate rim,
            // `revolutionAxis` has nothing to disagree with and would return it unconditionally
            // without the fix.
            let candidates = adjacentSurfaceKinds(graph, sliver.index).filter {
                $0 == .cylinder || $0 == .cone
            }
            #expect(candidates.count == 1)
            let result = alongEdge(graph, sliver.index)
            #expect(degenerateMessage(result) != nil, "expected .degenerate, got \(result)")
        }

        // The control, where only the length differs: the same construction with an arc that is
        // tiny but real (1e-6 rad, 5e-6 long) still resolves to the axis, at its own height.
        let shortCyl = try #require(Shape.cylinder(radius: 5, height: 10, angle: 1e-6), "short")
        let shortGraph = try #require(BRepGraph(shape: shortCyl), "graph of the short arc")
        let shortArcs = circleEdges(in: shortGraph)
        #expect(shortArcs.count == 2, "the top and the bottom arc")
        for arc in shortArcs {
            #expect(arc.edge.length > 1e-6 && arc.edge.length < 1e-5, "length \(arc.edge.length)")
            let onAxis = SIMD3<Double>(0, 0, arc.start.z)
            let expected = try rightHandedAxis(of: arc.edge, about: Self.zAxis, through: onAxis)
            let ax = try alongEdge(shortGraph, arc.index).get()
            #expect(isClose(ax.direction, expected), "short arc direction \(ax.direction)")
            #expect(isClose(ax.origin, onAxis), "short arc origin \(ax.origin)")
        }
    }

    @Test(
        "alongEdge on a cone's straight generatrix reparameterized as a BSpline keeps the chord, not the axis (#894 finding 1, second pass)"
    )
    func alongEdgeConeStraightSeamReparameterizedAsBSplineKeepsChord() throws {
        // A cone's lateral generatrix meets its axis at the cone's own nonzero half-angle, never
        // parallel to it, the old chord-parallel-to-axis check (removed by the third pass's
        // `coaxialCrossSection` rewrite) could never catch a straight seam on a CONE the way it
        // caught one on a cylinder (`alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord`
        // above). `coaxialCrossSection`'s radius/height-constancy test has no such blind spot: a
        // generatrix's radius from the axis varies continuously from apex to base, so it fails
        // the "radius stays constant" half of the check the same way a cylinder seam fails the
        // "height stays constant" half.
        let bottomRadius = 5.0
        let semiAngle = 0.3  // radians; nonzero, so this generatrix is never axis-parallel
        func radius(atHeight z: Double) -> Double { bottomRadius + z * tan(semiAngle) }
        let angle0 = 0.0
        let angle1 = 0.3
        let midAngle = (angle0 + angle1) / 2
        let p0bot = SIMD3(radius(atHeight: 0) * cos(angle0), radius(atHeight: 0) * sin(angle0), 0.0)
        let p0mid = SIMD3(radius(atHeight: 5) * cos(angle0), radius(atHeight: 5) * sin(angle0), 5.0)
        let p0top = SIMD3(
            radius(atHeight: 10) * cos(angle0), radius(atHeight: 10) * sin(angle0), 10.0)
        let p1bot = SIMD3(radius(atHeight: 0) * cos(angle1), radius(atHeight: 0) * sin(angle1), 0.0)
        let p1top = SIMD3(
            radius(atHeight: 10) * cos(angle1), radius(atHeight: 10) * sin(angle1), 10.0)

        let surface = try #require(
            Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: bottomRadius, semiAngle: semiAngle),
            "cone surface")
        let seamCurve = try #require(
            Curve3D.interpolate(points: [p0bot, p0mid, p0top]), "seam curve")
        let seamEdgeShape = try #require(Shape.edgeFromCurve(seamCurve), "seam edge shape")
        let seamEdge = try #require(Edge(seamEdgeShape), "seam edge")
        let otherSideWire = try #require(Wire.line(from: p1top, to: p1bot), "other side wire")
        let otherSideEdge = try #require(otherSideWire.edges().first, "other side edge")
        let topArcCurve = try #require(
            Curve3D.arcOfCircle(
                start: p0top,
                interior: SIMD3(
                    radius(atHeight: 10) * cos(midAngle), radius(atHeight: 10) * sin(midAngle),
                    10.0),
                end: p1top),
            "top arc curve")
        let topArcShape = try #require(Shape.edgeFromCurve(topArcCurve), "top arc shape")
        let topArcEdge = try #require(Edge(topArcShape), "top arc edge")
        let botArcCurve = try #require(
            Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(
                    radius(atHeight: 0) * cos(midAngle), radius(atHeight: 0) * sin(midAngle), 0.0),
                end: p0bot),
            "bottom arc curve")
        let botArcShape = try #require(Shape.edgeFromCurve(botArcCurve), "bottom arc shape")
        let botArcEdge = try #require(Edge(botArcShape), "bottom arc edge")
        let wire = try #require(
            Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]), "wire")
        let faceShape = try #require(Shape.face(from: surface, boundary: wire), "face")
        let graph = try #require(BRepGraph(shape: faceShape), "graph of the face")

        let seamNodeIndex = try #require(
            firstEdgeIndex(in: graph, curveType: .bsplineCurve), "no BSpline-curveType edge found")
        // Confirm the fixture matches the premise: the seam edge is adjacent to a cone-kind face
        // (so `revolutionAxis` has a candidate to redirect to at all).
        let coneFaceCount = adjacentSurfaceKinds(graph, seamNodeIndex).filter { $0 == .cone }.count
        #expect(coneFaceCount == 1)

        let ax = try alongEdge(graph, seamNodeIndex).get()
        // The chord and the cone's axis are NOT parallel (nonzero half-angle), unlike the
        // cylinder case, direction alone distinguishes "kept the chord" from "redirected to
        // the axis" here too, so both direction and origin are asserted directly against the
        // seam's own geometry, as vectors rather than through a dot-product threshold: the
        // chord is 0.3 rad away from the axis, so the two answers are far apart.
        let expectedDirection = simd_normalize(p0top - p0bot)
        #expect(isClose(ax.direction, expectedDirection), "direction \(ax.direction)")
        #expect(isClose(ax.origin, p0bot), "origin \(ax.origin), the seam starts at \(p0bot)")
    }

    @Test(
        "alongEdge derives its sign from the edge's own start->end order, not the adjacent surface's placement convention (#894 finding 2, second pass)"
    )
    func alongEdgeSignTracksEdgeTopologyNotSurfaceConvention() throws {
        // Two quarter-circle rims on the SAME cylinder wall, whose top-arc edges are
        // parameterized with `bounds.first` at opposite physical ends (pA->pB vs pB->pA).
        // `Face.primaryAxis` reads the same fixed direction off the shared wall surface either
        // way, so without a fix, both would silently resolve to the identical sign;
        // `resolveEdgeDirection` should instead track the parameterization difference, the same
        // way `dir = end - start` already does for a straight edge.
        //
        // `Shape.face(from:boundary:)`'s exact wire-fitting strategy on a periodic cylindrical
        // surface is sensitive to more than just "which point is which": which of the 4 boundary
        // edges are built in which raw curve direction, and in which order they're handed to
        // `Wire.wireFromEdges`, decides whether the fit succeeds or falls back to a crude
        // point-projected polygon (many tiny BSpline fragments instead of one clean arc). Both
        // constructions below were confirmed (by direct inspection) to build a clean 4-edge wire
        // with the top arc still `curveType == .circle`, not a fragmented approximation, an
        // arbitrary reshuffle of either one is not guaranteed to stay that way.
        let radius = 5.0
        let height = 10.0
        let angle0 = 0.0
        let angle1 = Double.pi / 2
        let midAngle = (angle0 + angle1) / 2
        let pA = SIMD3(radius * cos(angle0), radius * sin(angle0), height)
        let pB = SIMD3(radius * cos(angle1), radius * sin(angle1), height)
        let pMidTop = SIMD3(radius * cos(midAngle), radius * sin(midAngle), height)
        let qA = SIMD3(radius * cos(angle0), radius * sin(angle0), 0.0)
        let qB = SIMD3(radius * cos(angle1), radius * sin(angle1), 0.0)
        let qMidBot = SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0)

        /// The top arc's resolved axis and the point its own parameterization starts at.
        func topArc(from faceShape: Shape) throws -> (axis: Axis, start: SIMD3<Double>) {
            let graph = try #require(BRepGraph(shape: faceShape), "graph of the face")
            let top = try #require(
                circleEdges(in: graph).first(where: { abs($0.start.z - height) < 1e-6 }),
                "the circular top arc")
            return (try alongEdge(graph, top.index).get(), top.start)
        }

        // Top arc parameterized pA -> pB (bounds.first == pA).
        let surfaceForward = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius), "surface")
        let topArcForward = try #require(
            Curve3D.arcOfCircle(start: pA, interior: pMidTop, end: pB), "forward top arc")
        let topArcForwardShape = try #require(Shape.edgeFromCurve(topArcForward), "forward shape")
        let topArcForwardEdge = try #require(Edge(topArcForwardShape), "forward edge")
        let botArcForward = try #require(
            Curve3D.arcOfCircle(start: qB, interior: qMidBot, end: qA), "forward bottom arc")
        let botArcForwardShape = try #require(Shape.edgeFromCurve(botArcForward), "forward bottom")
        let botArcForwardEdge = try #require(Edge(botArcForwardShape), "forward bottom edge")
        let upForwardWire = try #require(Wire.line(from: qA, to: pA), "forward up wire")
        let upForwardEdge = try #require(upForwardWire.edges().first, "forward up edge")
        let downForwardWire = try #require(Wire.line(from: pB, to: qB), "forward down wire")
        let downForwardEdge = try #require(downForwardWire.edges().first, "forward down edge")
        let wireForward = try #require(
            Wire.wireFromEdges([
                upForwardEdge, topArcForwardEdge, downForwardEdge, botArcForwardEdge,
            ]), "forward wire")
        let faceForward = try #require(
            Shape.face(from: surfaceForward, boundary: wireForward), "forward face")
        let forward = try topArc(from: faceForward)

        // Top arc parameterized pB -> pA (bounds.first == pB), the physically identical rim,
        // opposite parameter order. Every other edge is rebuilt to match (see the wire-fitting
        // sensitivity noted above); this specific combination was confirmed by direct inspection
        // to also build a clean 4-edge wire.
        let surfaceReversed = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius), "surface")
        let topArcReversed = try #require(
            Curve3D.arcOfCircle(start: pB, interior: pMidTop, end: pA), "reversed top arc")
        let topArcReversedShape = try #require(
            Shape.edgeFromCurve(topArcReversed), "reversed shape")
        let topArcReversedEdge = try #require(Edge(topArcReversedShape), "reversed edge")
        let botArcReversed = try #require(
            Curve3D.arcOfCircle(start: qB, interior: qMidBot, end: qA), "reversed bottom arc")
        let botArcReversedShape = try #require(
            Shape.edgeFromCurve(botArcReversed), "reversed bottom")
        let botArcReversedEdge = try #require(Edge(botArcReversedShape), "reversed bottom edge")
        let eReversed1Wire = try #require(Wire.line(from: pB, to: qB), "reversed wire 1")
        let eReversed1 = try #require(eReversed1Wire.edges().first, "reversed edge 1")
        let eReversed2Wire = try #require(Wire.line(from: qA, to: pA), "reversed wire 2")
        let eReversed2 = try #require(eReversed2Wire.edges().first, "reversed edge 2")
        let wireReversed = try #require(
            Wire.wireFromEdges([
                eReversed1, topArcReversedEdge, eReversed2, botArcReversedEdge,
            ]), "reversed wire")
        let faceReversed = try #require(
            Shape.face(from: surfaceReversed, boundary: wireReversed), "reversed face")
        let reversed = try topArc(from: faceReversed)

        // The two fixtures really are the same rim traversed from opposite ends.
        #expect(isClose(forward.start, pA), "forward arc starts at \(forward.start)")
        #expect(isClose(reversed.start, pB), "reversed arc starts at \(reversed.start)")

        // Same physical axis either way, on the centerline at the rim's height, and the sign
        // follows the traversal by the right-hand rule: pA (0 degrees) to pB (90 degrees) is
        // counterclockwise seen from +Z, so +Z, and the same arc walked pB to pA is -Z. Pinned
        // absolutely, not only against each other: two resolvers that both flipped would still
        // disagree with each other.
        let onAxis = SIMD3<Double>(0, 0, height)
        #expect(isClose(forward.axis.origin, onAxis), "forward origin \(forward.axis.origin)")
        #expect(isClose(reversed.axis.origin, onAxis), "reversed origin \(reversed.axis.origin)")
        #expect(isClose(forward.axis.direction, Self.zAxis), "forward \(forward.axis.direction)")
        #expect(
            isClose(reversed.axis.direction, -Self.zAxis), "reversed \(reversed.axis.direction)")
    }

    @Test(
        "alongEdge on a helical thread edge does not silently return the cylinder's centerline (#894 finding 3, second pass)"
    )
    func alongEdgeHelicalEdgeDoesNotSilentlyReturnCenterline() throws {
        // A helix's two-point secant can land nearly parallel to the cylinder's axis purely from
        // the sweep angle, the old chord-parallel-to-axis check (removed by the third pass's
        // `coaxialCrossSection` rewrite) could misfire on this. `coaxialCrossSection`'s
        // height-constancy check has no such blind spot: sampling interior points along a genuine
        // helix shows height varying continuously across the whole span, unlike a true
        // perpendicular cross-section.
        //
        // The fixture is a half turn, from 45 to 225 degrees, not the full turn that would make
        // the secant exactly axis-parallel. This test used to build the full turn, and measured,
        // it never contained a helix: `Shape.face(from:boundary:)` could not fit a wire that
        // touches the cylinder's seam, fell back to projecting points, and left 622 edges of a
        // few hundredths of a unit each, so the "helical edge" the test picked was the first
        // non-line fragment of that shredding. The half turn avoids the seam, and the helix is
        // approximated to 1e-8 (the 1e-3 default is too loose for the exact fit, which then
        // shreds it the same way), so it arrives as the single edge this test is about.
        let radius = 5.0
        let pitch = 10.0
        let start = Double.pi / 4
        let helixBuild = try #require(
            Helix.build(
                origin: .zero, direction: SIMD3(0, 0, 1),
                xDirection: SIMD3(cos(start), sin(start), 0),
                parameterRange: 0...Double.pi, pitch: pitch, radius: radius, isClockwise: true,
                tolerance: 1e-8),
            "helix")
        // Where the construction says the half turn starts and ends: the point at 45 degrees on
        // the floor, and the point at 225 degrees half a pitch up.
        let helixStart = SIMD3<Double>(radius * cos(start), radius * sin(start), 0)
        let end = 5 * Double.pi / 4
        let helixEnd = SIMD3<Double>(radius * cos(end), radius * sin(end), pitch / 2)

        let surface = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius), "surface")
        let helixEdgeShape = try #require(Shape.edgeFromCurve(helixBuild.curve), "helix shape")
        let helixEdge = try #require(Edge(helixEdgeShape), "helix edge")
        // A vertical line down from the helix's end and a floor arc back to its start, round
        // through 135 degrees, close the wire on the wall.
        let floorEnd = SIMD3<Double>(helixEnd.x, helixEnd.y, 0)
        let downWire = try #require(Wire.line(from: helixEnd, to: floorEnd), "vertical wire")
        let downEdge = try #require(downWire.edges().first, "vertical edge")
        let floorMid = SIMD3<Double>(
            radius * cos(3 * Double.pi / 4), radius * sin(3 * Double.pi / 4), 0)
        let floorStart = SIMD3<Double>(helixStart.x, helixStart.y, 0)
        let floorCurve = try #require(
            Curve3D.arcOfCircle(start: floorEnd, interior: floorMid, end: floorStart), "floor arc")
        let floorShape = try #require(Shape.edgeFromCurve(floorCurve), "floor arc shape")
        let floorEdge = try #require(Edge(floorShape), "floor arc edge")
        let wire = try #require(
            Wire.wireFromEdges([helixEdge, downEdge, floorEdge]), "wire")
        let faceShape = try #require(Shape.face(from: surface, boundary: wire), "face")
        let graph = try #require(BRepGraph(shape: faceShape), "graph of the face")

        // The fixture means what it says: three edges, the helix whole among them.
        #expect(graph.edgeCount == 3, "the helix, the vertical line and the floor arc")
        let helixIndex = try #require(
            firstEdgeIndex(in: graph, curveType: .bsplineCurve), "the helical BSpline edge")
        // Adjacent to exactly one cylinder-kind face, same as a genuine rim, `revolutionAxis`
        // has nothing to disagree with, so only `coaxialCrossSection`'s own height check can
        // decline the redirect.
        let cylFaceCount = adjacentSurfaceKinds(graph, helixIndex).filter { $0 == .cylinder }.count
        #expect(cylFaceCount == 1)
        let measuredShape = try #require(
            graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: helixIndex), "helix shape")
        let measured = try #require(measuredShape.edges().first, "helix edge in the graph")
        let measuredBounds = try #require(measured.parameterBounds, "helix bounds")
        let measuredStart = try #require(measured.point(at: measuredBounds.first), "helix start")
        let measuredEnd = try #require(measured.point(at: measuredBounds.last), "helix end")
        #expect(isClose(measuredStart, helixStart, 1e-6), "helix starts at \(measuredStart)")
        #expect(isClose(measuredEnd, helixEnd, 1e-6), "helix ends at \(measuredEnd)")

        // The chord fallback: origin is the helix's own start point (on the cylinder wall, never
        // on the centerline) and the direction is the secant, which climbs and turns and is
        // nowhere near the axis.
        let ax = try alongEdge(graph, helixIndex).get()
        #expect(isClose(ax.origin, helixStart, 1e-6), "origin \(ax.origin), helix start")
        let secant = simd_normalize(helixEnd - helixStart)
        #expect(isClose(ax.direction, secant, 1e-6), "direction \(ax.direction), secant \(secant)")
        #expect(abs(simd_dot(ax.direction, Self.zAxis)) < 0.5, "direction \(ax.direction)")

        // The control, on the same face: its floor arc IS a perpendicular cross-section of the
        // wall and does resolve to the axis, on the centerline at its own height, running the
        // way the arc turns. It goes from 225 down to 45 degrees, clockwise seen from +Z, so -Z.
        let floorIndex = try #require(
            circleEdges(in: graph).first?.index, "the floor arc in the graph")
        let floorAxis = try alongEdge(graph, floorIndex).get()
        #expect(
            isClose(floorAxis.origin, SIMD3<Double>(0, 0, 0)), "floor origin \(floorAxis.origin)")
        #expect(isClose(floorAxis.direction, -Self.zAxis), "floor direction \(floorAxis.direction)")
    }

    // MARK: - throughPoints and intersectionOfPlanes

    @Test("throughPoints on coincident vertices fails with degenerate")
    func coincidentPointsDegenerate() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        let coincident = graph.resolve(ConstructionAxis.throughPoints(v, v))
        #expect(degenerateMessage(coincident) != nil, "expected degenerate, got \(coincident)")

        // The control: two distinct vertices resolve, through the first one and towards the
        // second, with the vertex positions read through a different bridge call than the
        // resolver uses. Swapping them swaps both the origin and the sign of the direction.
        let v7 = TopologyRef.literal(.init(kind: .vertex, index: 7))
        let p0 = graph.vertexPoint(0)
        let p7 = graph.vertexPoint(7)
        let from = SIMD3<Double>(p0.x, p0.y, p0.z)
        let to = SIMD3<Double>(p7.x, p7.y, p7.z)
        let forward = try graph.resolve(ConstructionAxis.throughPoints(v, v7)).get()
        #expect(isClose(forward.origin, from), "origin \(forward.origin), first point \(from)")
        #expect(isClose(forward.direction, simd_normalize(to - from)), "\(forward.direction)")
        let backward = try graph.resolve(ConstructionAxis.throughPoints(v7, v)).get()
        #expect(isClose(backward.origin, to), "origin \(backward.origin), first point \(to)")
        #expect(isClose(backward.direction, simd_normalize(from - to)), "\(backward.direction)")
    }

    @Test("intersectionOfPlanes on parallel planes fails with degenerate")
    func parallelIntersectionDegenerate() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        let a = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let b = ConstructionPlane.absolute(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        let parallel = graph.resolve(ConstructionAxis.intersectionOfPlanes(a, b))
        #expect(degenerateMessage(parallel) != nil, "expected degenerate, got \(parallel)")
        // Planes facing opposite ways are just as parallel.
        let c = ConstructionPlane.absolute(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, -1))
        let opposed = graph.resolve(ConstructionAxis.intersectionOfPlanes(a, c))
        #expect(degenerateMessage(opposed) != nil, "expected degenerate, got \(opposed)")

        // The control: z = 3 and x = 4, whose plane origins are both ON their common line
        // {x = 4, z = 3}. The line runs along cross(nA, nB) = Z x X = +Y (and -Y with the planes
        // swapped), and the origin lies on both planes.
        let planeA = ConstructionPlane.absolute(origin: SIMD3(4, 5, 3), normal: SIMD3(0, 0, 1))
        let planeB = ConstructionPlane.absolute(origin: SIMD3(4, -5, 3), normal: SIMD3(1, 0, 0))
        let crossing = try graph.resolve(ConstructionAxis.intersectionOfPlanes(planeA, planeB))
            .get()
        #expect(isClose(crossing.direction, SIMD3<Double>(0, 1, 0)), "\(crossing.direction)")
        #expect(abs(crossing.origin.z - 3.0) < 1e-9, "origin \(crossing.origin) is off z = 3")
        #expect(abs(crossing.origin.x - 4.0) < 1e-9, "origin \(crossing.origin) is off x = 4")
        let swapped = try graph.resolve(ConstructionAxis.intersectionOfPlanes(planeB, planeA)).get()
        #expect(isClose(swapped.direction, SIMD3<Double>(0, -1, 0)), "\(swapped.direction)")
    }

    @Test("intersectionOfPlanes anchors its axis on the line the two planes share (#3037)")
    func intersectionOfPlanesOriginLiesOnBothPlanes() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        // z = 0 and x = 10, whose own origins are NOT on their common line {x = 10, z = 0}.
        let a = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let b = ConstructionPlane.absolute(origin: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0))
        let axis = try graph.resolve(ConstructionAxis.intersectionOfPlanes(a, b)).get()
        // The direction is right whatever the origin is.
        #expect(isClose(axis.direction, SIMD3<Double>(0, 1, 0)), "direction \(axis.direction)")
        // The origin is the midpoint of the two plane origins, (5, 0, 0): on z = 0 and not on
        // x = 10, so the axis is parallel to the real intersection and 5 away from it (#3037).
        // This records the correct expectation and goes red when the defect is fixed, at which
        // point the wrapper comes off.
        withKnownIssue("#3037: the origin is the midpoint of the plane origins, off the line") {
            #expect(abs(axis.origin.z) < 1e-9, "origin \(axis.origin) is off the plane z = 0")
            #expect(
                abs(axis.origin.x - 10.0) < 1e-9, "origin \(axis.origin) is off the plane x = 10")
        }
    }

    // MARK: - normalToFace

    @Test(
        "normalToFace on a cylinder returns the rotation axis, not the local radial normal (#882)")
    func normalToFaceCylinderPrimaryAxis() throws {
        // The doc promises the cylinder's own rotation axis (here unit Z). Before
        // #882, normalToFace returned the UV-midpoint radial normal instead,
        // which lies in the XY plane and has zero Z component.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10), "cylinder")
        let graph = try #require(BRepGraph(shape: cyl), "graph of the cylinder")
        // The lateral wall by kind, not by an assumed index: a cap would also answer +-Z and
        // could not tell the axis from the radial normal.
        let wall = try #require(faceIndex(in: graph, withAxisKind: .cylinder), "the lateral face")
        #expect(graph.vertexCount == 2)
        for vertexIndex in 0..<graph.vertexCount {
            let ax = try normalToFace(graph, face: wall, vertex: vertexIndex).get()
            #expect(isClose(ax.direction, Self.zAxis), "vertex \(vertexIndex): \(ax.direction)")
        }
    }

    @Test(
        "normalToFace on a cylinder anchors the returned axis on the true centerline, not the off-axis vertex it was asked at (PR #897 review, third pass)"
    )
    func normalToFaceCylinderOriginOnAxis() throws {
        // The cylinder's two vertices sit ON the lateral surface, radius 5 from the true
        // centerline (the Z axis, since Shape.cylinder is centered on it), one at the top and one
        // at the bottom. Before this fix, normalToFace's returned origin was always the raw,
        // off-axis vertex position, pairing a correct axis DIRECTION with a WRONG axis LOCATION,
        // a line parallel to, but offset by the full radius from, the true rotation axis.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10), "cylinder")
        let graph = try #require(BRepGraph(shape: cyl), "graph of the cylinder")
        let wall = try #require(faceIndex(in: graph, withAxisKind: .cylinder), "the lateral face")
        var heights: [Double] = []
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            heights.append(raw.z)
            let ax = try normalToFace(graph, face: wall, vertex: vertexIndex).get()
            // On the centerline (radial distance 0 from the Z axis), kept edge-local: projected
            // at the requested vertex's own height along the axis, not snapped to the surface's
            // own placement origin elsewhere on the axis. The two vertices are at different
            // heights, so a snap to the placement origin (0, 0, 0) is wrong for one of them.
            #expect(
                isClose(ax.origin, SIMD3<Double>(0, 0, raw.z)),
                "vertex \(vertexIndex): \(ax.origin)")
            #expect(isClose(ax.direction, Self.zAxis), "vertex \(vertexIndex): \(ax.direction)")
        }
        heights.sort()
        try #require(heights.count == 2)
        #expect(abs(heights[1] - heights[0] - 10.0) < 1e-9, "vertex heights \(heights)")

        // The same on a cylinder whose axis is neither Z nor through the origin, where a formula
        // that quietly assumed a vertical axis would be wrong. The expected origin is each vertex
        // projected onto the axis line the cylinder was BUILT on, and the expected direction is
        // the direction it was built with.
        let base = SIMD3<Double>(1, 2, 3)
        let axisDirection = simd_normalize(SIMD3<Double>(1, 2, 2))
        let tilted = try #require(
            Shape.cylinder(at: base, direction: axisDirection, radius: 5, height: 10),
            "tilted cylinder")
        let tiltedGraph = try #require(BRepGraph(shape: tilted), "graph of the tilted cylinder")
        let tiltedWall = try #require(
            faceIndex(in: tiltedGraph, withAxisKind: .cylinder), "the tilted lateral face")
        var along: [Double] = []
        for vertexIndex in 0..<tiltedGraph.vertexCount {
            let raw = tiltedGraph.vertexPoint(vertexIndex)
            let vertex = SIMD3<Double>(raw.x, raw.y, raw.z)
            let reach = simd_dot(vertex - base, axisDirection)
            along.append(reach)
            let expectedOrigin = base + reach * axisDirection
            let ax = try normalToFace(tiltedGraph, face: tiltedWall, vertex: vertexIndex).get()
            #expect(isClose(ax.origin, expectedOrigin), "vertex \(vertexIndex): \(ax.origin)")
            #expect(isClose(ax.direction, axisDirection), "vertex \(vertexIndex): \(ax.direction)")
        }
        along.sort()
        try #require(along.count == 2)
        #expect(
            abs(along[0]) < 1e-9 && abs(along[1] - 10.0) < 1e-9, "heights along the axis \(along)")
    }

    @Test(
        "normalToFace on a torus also anchors the returned axis on the true centerline, not the vertex's own far-off-axis position (PR #897 review, third pass)"
    )
    func normalToFaceTorusOriginOnAxis() throws {
        // A torus's single seam vertex sits at (majorRadius + minorRadius) from the true
        // centerline, 25 units here, the widest point on the whole surface, so this is the most
        // extreme case of the same bug the cylinder test above covers, and the only fixture in
        // this suite that exercises the axis-projection formula for a kind other than
        // `.cylinder` (`.cone`/`.torus`/`.revolution` share the identical code path, but only
        // `.cylinder` had a dedicated origin test before this one).
        //
        // That seam vertex is also in the torus's own mid-plane, so its height along the axis is
        // 0 and so is the surface's placement origin: it cannot tell a projection from a snap to
        // that origin. The torus therefore shares a compound with a box centred on the origin,
        // whose corners sit at heights of +-5, and `at` is asked at every vertex of both.
        let torus = try #require(Shape.torus(majorRadius: 20, minorRadius: 5), "torus")
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let compound = try #require(Shape.compound([torus, box]), "torus and box")
        let graph = try #require(BRepGraph(shape: compound), "graph of the compound")
        let torusFace = try #require(faceIndex(in: graph, withAxisKind: .torus), "toroidal face")
        #expect(graph.vertexCount == 9, "the torus's seam vertex and the box's eight corners")
        var heights = Set<Int>()
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            heights.insert(Int((raw.z).rounded()))
            let ax = try normalToFace(graph, face: torusFace, vertex: vertexIndex).get()
            // On the true centerline, at the vertex's own height along the axis, pointing along it.
            #expect(
                isClose(ax.origin, SIMD3<Double>(0, 0, raw.z)),
                "vertex \(vertexIndex): \(ax.origin)")
            #expect(isClose(ax.direction, Self.zAxis), "vertex \(vertexIndex): \(ax.direction)")
        }
        #expect(heights == [-5, 0, 5], "the vertices must sit at three different heights")
    }

    @Test("normalToFace on a planar face still returns the face normal")
    func normalToFacePlaneFallback() throws {
        // Planes have no primary axis, so normalToFace must fall back to the surface normal at
        // the projection of `at` onto the face, with that projected point as the origin.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        #expect(graph.faceCount == 6)
        #expect(graph.vertexCount == 8)
        for faceIndex in 0..<graph.faceCount {
            let faceShape = try #require(
                graph.shape(nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                "shape of face \(faceIndex)")
            let centroids = faceShape.measure().faceCentroids
            let centroid = try #require(centroids.first ?? nil, "centroid of face \(faceIndex)")
            // Shape.box is centred on the origin, so a face's outward normal is its own centroid
            // scaled to unit length: derived from the box, not from `Face.normal`.
            let outward = simd_normalize(centroid)
            for vertexIndex in 0..<graph.vertexCount {
                let raw = graph.vertexPoint(vertexIndex)
                let vertex = SIMD3<Double>(raw.x, raw.y, raw.z)
                let ax = try normalToFace(graph, face: faceIndex, vertex: vertexIndex).get()
                #expect(
                    isClose(ax.direction, outward),
                    "face \(faceIndex), vertex \(vertexIndex): \(ax.direction)")
                // The origin is `at` projected onto the plane of the face, which is the vertex
                // itself for the four vertices on the face and a point of the plane otherwise.
                let projected = vertex - simd_dot(vertex - centroid, outward) * outward
                #expect(
                    isClose(ax.origin, projected),
                    "face \(faceIndex), vertex \(vertexIndex): \(ax.origin)")
            }
        }
    }

    @Test(
        "normalToFace on an extrusion-surface face falls back to the UV-midpoint normal, not the sweep direction (PR #897 review)"
    )
    func normalToFaceExtrusionFallsBackToNormal() throws {
        // Geom_SurfaceOfLinearExtrusion's primaryAxis.direction is the SWEEP direction
        // (tangent to the surface), not a normal, unlike cylinder/cone/sphere/torus/
        // revolution, where primaryAxis.direction genuinely is a rotation axis. A
        // straight-line profile (along X) extruded along Z produces a planar surface
        // whose true normal (Y) is perpendicular to both the profile and the sweep
        // direction; before this fix, normalToFace returned the sweep direction
        // (Z) unconditionally whenever primaryAxis was non-nil.
        let line = try #require(
            Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)), "profile")
        let surface = try #require(
            Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)), "extrusion surface")
        let extrudedFace = try #require(
            Shape.face(from: surface, uRange: 0...10, vRange: 0...10), "extruded face")
        let graph = try #require(BRepGraph(shape: extrudedFace), "graph of the extruded face")

        // Sanity: this fixture really does have an extrusion-kind primaryAxis along
        // the sweep direction, so the test is exercising the branch it claims to.
        let face = try #require(
            graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first, "the face")
        let axis = try #require(face.primaryAxis, "the primary axis")
        #expect(axis.kind == .extrusion, "fixture is not an extrusion-surface face")
        #expect(abs(axis.direction.z) > 0.99, "sweep direction should be along Z")

        // The surface is S(u, v) = (u, 0, v), so its normal d_u x d_v = X x Z = -Y, and the
        // fallback samples it, with its point, at the UV midpoint (5, 0, 5). Neither depends on
        // which vertex `at` names.
        #expect(graph.vertexCount == 4)
        for vertexIndex in 0..<graph.vertexCount {
            let ax = try normalToFace(graph, face: 0, vertex: vertexIndex).get()
            #expect(
                isClose(ax.direction, SIMD3<Double>(0, -1, 0)),
                "vertex \(vertexIndex): \(ax.direction)")
            #expect(
                isClose(ax.origin, SIMD3<Double>(5, 0, 5)), "vertex \(vertexIndex): \(ax.origin)")
        }
    }

    @Test(
        "normalToFace on a spherical face falls back to the UV-midpoint normal, not the arbitrary pole axis (PR #897 review, 3rd pass)"
    )
    func normalToFaceSphereFallsBackToNormal() throws {
        // gp_Sphere::Position().Direction() (what Face.primaryAxis reports for a
        // sphere) is just the arbitrary construction-frame pole: a sphere is
        // symmetric about every axis through its center, so unlike
        // cylinder/cone/torus/revolution it has no intrinsic rotation axis at all.
        // Before this fix, normalToFace returned that same fixed (0,0,1) pole
        // direction for every vertex on the sphere, off by 90 degrees from the true
        // local normal at the equator.
        let radius = 5.0
        let sph = try #require(Shape.sphere(radius: radius), "sphere")
        let graph = try #require(BRepGraph(shape: sph), "graph of the sphere")

        // Sanity: this fixture really does have a sphere-kind primaryAxis, so the
        // test is exercising the branch it claims to.
        let face = try #require(
            graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first, "the face")
        let axis = try #require(face.primaryAxis, "the primary axis")
        #expect(axis.kind == .sphere, "fixture is not a spherical face")
        let poleDirection = simd_normalize(axis.direction)

        // Find the two real pole vertices by position, not by assuming fixed indices 0/1 --
        // vertex enumeration order isn't guaranteed stable across an OCCT kernel rebuild or
        // platform (CLAUDE.md Test Conventions; #897 review, second xhigh pass, finding 4) --
        // matching `tangentToFaceConeApexFallsBackToNormal`'s own by-position search.
        var poleIndices: [Int] = []
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let offset = SIMD3(raw.x, raw.y, raw.z) - axis.origin
            let axial = simd_dot(offset, poleDirection)
            let radial = offset - axial * poleDirection
            if abs(abs(axial) - radius) < 1e-6, simd_length(radial) < 1e-6 {
                poleIndices.append(vertexIndex)
            }
        }
        try #require(poleIndices.count == 2, "expected exactly 2 pole vertices")

        // The origin and direction must come from the SAME location, the UV midpoint, not the
        // raw, off-face pole vertex paired with a normal sampled elsewhere (#897 review, third
        // pass, finding 2).
        let sample = try #require(face.uvMidpointSample(), "uvMidpointSample unavailable")
        let expectedFallbackPoint = sample.0
        let expectedFallbackNormal = sample.1

        // And that midpoint is where the sphere's parameterization puts it: u runs 0...2*pi and
        // v runs -pi/2...pi/2, so the midpoint is (u, v) = (pi, 0), the equator point (-5, 0, 0),
        // whose outward normal is the radial direction (-1, 0, 0). Derived from the sphere, so a
        // `uvMidpointSample` that returned the wrong sample could not agree with it by accident.
        #expect(
            isClose(expectedFallbackPoint, SIMD3<Double>(-radius, 0, 0)), "\(expectedFallbackPoint)"
        )
        #expect(
            isClose(simd_normalize(expectedFallbackNormal), SIMD3<Double>(-1, 0, 0)),
            "\(expectedFallbackNormal)")

        // Checked at both poles to show the exclusion holds regardless of which vertex is asked.
        for vertexIndex in poleIndices {
            let ax = try normalToFace(graph, face: 0, vertex: vertexIndex).get()
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
            // The old, broken code returned the fixed pole axis unconditionally; the fallback
            // UV-midpoint normal (at the sphere's equator) is perpendicular to it instead.
            #expect(abs(simd_dot(ax.direction, poleDirection)) < 1e-9, "pole \(vertexIndex)")
            #expect(simd_length(ax.origin - expectedFallbackPoint) < 1e-6, "pole \(vertexIndex)")
            #expect(
                simd_length(simd_normalize(ax.direction) - simd_normalize(expectedFallbackNormal))
                    < 1e-6, "pole \(vertexIndex)")
        }
    }

    /// The saddle (hyperbolic-paraboloid) Bezier patch the two free-form tests share.
    ///
    /// Poles `[[(0,0,0), (0,3,3)], [(3,0,3), (3,3,0)]]` make the bilinear patch
    /// S(u, v) = (3u, 3v, 3u + 3v - 6uv), whose normal d_u x d_v is proportional to
    /// (2v - 1, 2u - 1, 1) (the constant 9 divides out). The four corner poles are non-coplanar
    /// (p11 != p01 + p10 - p00), which is what makes this a genuine saddle rather than a plane.
    private func saddleSurface() throws -> Surface {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 3, 3)],
            [SIMD3(3, 0, 3), SIMD3(3, 3, 0)],
        ]
        return try #require(Surface.bezier(poles: poles), "saddle surface")
    }

    @Test(
        "normalToFace on a free-form face is point-aware, not a fixed UV-midpoint normal (PR #897 review, finding 4)"
    )
    func normalToFaceFreeFormVariesWithPoint() throws {
        // A non-planar (saddle / hyperbolic-paraboloid) bilinear Bezier patch: doubly ruled,
        // genuinely curved, and has NO primaryAxis at all (only cylinder/cone/torus/sphere/
        // revolution/extrusion surfaces do), its true local normal varies substantially
        // across the surface.
        let surface = try saddleSurface()
        let face = try #require(
            Shape.face(from: surface, uBounds: 0...1, vBounds: 0...1), "saddle face")
        let graph = try #require(BRepGraph(shape: face), "graph of the saddle")

        // Sanity: this fixture really has no primaryAxis, so the test exercises the no-axis
        // fallback branch it claims to.
        let occFace = try #require(
            graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first, "face 0")
        #expect(occFace.primaryAxis == nil, "fixture should have no primary axis")

        // Before this fix, every vertex answered the SAME fixed UV-midpoint normal regardless of
        // `at`; this saddle's corners have genuinely different local normals, and each is known
        // in closed form: a corner at (x, y, z) has u = x / 3 and v = y / 3, so its normal is
        // (2v - 1, 2u - 1, 1) normalised, e.g. (-1, -1, 1) / sqrt(3) at the origin corner. The
        // origin is the corner itself, which already lies on the face.
        #expect(graph.vertexCount == 4)
        var normals: [SIMD3<Double>] = []
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let u = raw.x / 3.0
            let v = raw.y / 3.0
            let expected = simd_normalize(SIMD3<Double>(2.0 * v - 1.0, 2.0 * u - 1.0, 1.0))
            normals.append(expected)
            let ax = try normalToFace(graph, face: 0, vertex: vertexIndex).get()
            #expect(isClose(ax.direction, expected), "corner \(vertexIndex): \(ax.direction)")
            #expect(
                isClose(ax.origin, SIMD3<Double>(raw.x, raw.y, raw.z)),
                "corner \(vertexIndex): \(ax.origin)")
        }
        // The four expected normals are four different directions: the premise of the test.
        for i in 0..<normals.count {
            for j in (i + 1)..<normals.count {
                #expect(simd_dot(normals[i], normals[j]) < 0.99, "corners \(i) and \(j)")
            }
        }
    }

    @Test(
        "normalToFace: the returned origin is the actual on-face point the direction was evaluated at, not `at`'s raw position, when `at` doesn't lie on `face` (PR #897 review, second xhigh pass, finding 2)"
    )
    func normalToFaceOriginIsOnFaceNotRawPoint() throws {
        // Same saddle fixture as normalToFaceFreeFormVariesWithPoint above (no primaryAxis, so
        // this exercises resolveFaceAxisDirection's point-aware fallback branch), but `at` is a
        // vertex from a SEPARATE box shape entirely, the same "genuine misuse" pattern
        // tangentToFaceOriginIsOnFaceNotRawPoint already uses for tangentToFace.
        //
        // The box corner is placed one unit off the patch along its own normal at
        // (u, v) = (0.25, 0.75): the patch point S = (0.75, 2.25, 1.875), whose normal is
        // (0.5, -0.5, 1) normalised. A point on a surface normal at a distance well inside the
        // radius of curvature (about 4 here) projects straight back onto that foot point, so the
        // expected origin and direction are known in closed form, and are neither the raw corner
        // nor the patch's UV midpoint (1.5, 1.5, 1.5) with normal +Z.
        let surface = try saddleSurface()
        let saddleFace = try #require(
            Shape.face(from: surface, uBounds: 0...1, vBounds: 0...1), "saddle face")
        let foot = SIMD3<Double>(0.75, 2.25, 1.875)
        let normal = simd_normalize(SIMD3<Double>(0.5, -0.5, 1.0))
        let corner = foot + normal
        let box = try #require(
            Shape.box(origin: corner, width: 10, height: 10, depth: 10), "box with a corner at P")
        let compound = try #require(Shape.compound([saddleFace, box]), "saddle and box")
        let graph = try #require(BRepGraph(shape: compound), "graph of the compound")

        // Saddle added first: confirm face 0 of the compound really is the saddle, not the
        // box, and really has no primaryAxis.
        let saddle = try #require(
            graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first, "face 0")
        #expect(saddle.primaryAxis == nil, "face 0 of the compound is not the no-axis saddle")

        // The vertex that is the box's corner at P.
        var cornerIndex: Int?
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            if isClose(SIMD3<Double>(raw.x, raw.y, raw.z), corner, 1e-9) {
                cornerIndex = vertexIndex
            }
        }
        let offFaceVertexIndex = try #require(cornerIndex, "the box corner at P among the vertices")

        let ax = try normalToFace(graph, face: 0, vertex: offFaceVertexIndex).get()
        // The origin must be the actual on-face projected point, the same location the
        // direction was evaluated at, not the raw off-face vertex position, and it is a point of
        // the surface: z = 3u + 3v - 6uv with u = x / 3, v = y / 3, that is z = x + y - 2xy / 3.
        #expect(isClose(ax.origin, foot, 1e-6), "origin \(ax.origin), the foot point is \(foot)")
        let surfaceZ = ax.origin.x + ax.origin.y - 2.0 * ax.origin.x * ax.origin.y / 3.0
        #expect(abs(ax.origin.z - surfaceZ) < 1e-6, "origin \(ax.origin) is off the surface")
        #expect(simd_distance(ax.origin, corner) > 0.5, "origin should differ from the raw point")
        #expect(isClose(ax.direction, normal, 1e-6), "direction \(ax.direction), normal \(normal)")
    }

    // MARK: - Fail-loud edges and the cross-section tolerance

    @Test(
        "alongEdge fails loudly, not silently, when the edge's tangent is undefined at its own start point (#894 finding 1, fifth pass)"
    )
    func alongEdgeUndefinedStartTangentFailsLoudNotSilent() throws {
        // A quarter-turn "top arc" on a cylindrical wall, geometrically a genuine circular
        // cross-section, constant height/radius across all 5 of `coaxialCrossSection`'s own
        // sampled fractions, built as a degree-1 BSpline whose first two poles are IDENTICAL: a
        // textbook cusp (the segment [0, 0.05] has zero length, so the right-derivative at u=0 is
        // the zero vector). `GeomLProp_CLProps::IsTangentDefined()`, and so `Edge.tangent(at:)`
        // , correctly reports undefined there, while `Edge.point(at:)` at the same parameter
        // still succeeds (plain D0 evaluation, unaffected by a degenerate derivative).
        //
        // Knots are placed at exactly the 5 fractions `coaxialCrossSection` samples (0, 0.25,
        // 0.5, 0.75, 1.0), with the extra cusp pole tucked into [0, 0.05], so every sample lands
        // exactly on a pole (an exact circle point), not on a chord between two knots, the same
        // "poles are the samples" trick `coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise`
        // below uses to avoid a chord's corner-cutting error.
        let radius = 5.0
        let height = 10.0
        func circlePoint(_ angleDeg: Double) -> SIMD3<Double> {
            let a = angleDeg * Double.pi / 180
            return SIMD3(radius * cos(a), radius * sin(a), height)
        }
        let poles = [
            circlePoint(0), circlePoint(0), circlePoint(22.5), circlePoint(45),
            circlePoint(67.5), circlePoint(90),
        ]
        let knots: [Double] = [0, 0.05, 0.25, 0.5, 0.75, 1.0]
        let mults: [Int32] = [2, 1, 1, 1, 1, 2]

        let angle0 = 0.0
        let angle1 = Double.pi / 2
        let midAngle = (angle0 + angle1) / 2
        let p0bot = SIMD3(radius * cos(angle0), radius * sin(angle0), 0.0)
        let p1bot = SIMD3(radius * cos(angle1), radius * sin(angle1), 0.0)
        let p0top = circlePoint(0)
        let p1top = circlePoint(90)

        let surface = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius), "surface")
        let cuspCurve = try #require(
            Curve3D.bspline(poles: poles, knots: knots, multiplicities: mults, degree: 1),
            "cusp curve")
        let topArcShape = try #require(Shape.edgeFromCurve(cuspCurve), "cusp shape")
        let topArcEdge = try #require(Edge(topArcShape), "cusp edge")
        let seamWire = try #require(Wire.line(from: p0bot, to: p0top), "seam wire")
        let seamEdge = try #require(seamWire.edges().first, "seam edge")
        let otherSideWire = try #require(Wire.line(from: p1top, to: p1bot), "other side wire")
        let otherSideEdge = try #require(otherSideWire.edges().first, "other side edge")
        let botArcCurve = try #require(
            Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0),
                end: p0bot),
            "bottom arc curve")
        let botArcShape = try #require(Shape.edgeFromCurve(botArcCurve), "bottom arc shape")
        let botArcEdge = try #require(Edge(botArcShape), "bottom arc edge")
        let wire = try #require(
            Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]), "wire")
        let faceShape = try #require(Shape.face(from: surface, boundary: wire), "face")
        let graph = try #require(BRepGraph(shape: faceShape), "graph of the face")

        // Confirm the fixture matches the intended scenario, the cusp edge really is
        // BSpline-typed and really does have an undefined start tangent, before asserting on
        // the fix, rather than assuming the construction above behaved as designed.
        let cuspNodeIndex = try #require(
            firstEdgeIndex(in: graph, curveType: .bsplineCurve), "no BSpline-curveType edge found")
        let cuspShape = try #require(
            graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: cuspNodeIndex), "cusp shape")
        let cuspEdge = try #require(cuspShape.edges().first, "cusp edge")
        let cuspBounds = try #require(cuspEdge.parameterBounds, "cusp bounds")
        #expect(cuspEdge.tangent(at: cuspBounds.first) == nil)
        #expect(cuspEdge.point(at: cuspBounds.first) != nil)

        // Pre-fix, this silently kept `Face.primaryAxis`'s unflipped sign and returned `.success`
        // with a plausible-looking but potentially-wrong-signed axis. Fixed: fails loud instead,
        // and says why, so it is this failure and not some other degenerate one.
        let result = alongEdge(graph, cuspNodeIndex)
        let message = try #require(degenerateMessage(result), "expected .degenerate, got \(result)")
        #expect(message.contains("tangent"), "the failure should name the tangent: \(message)")
    }

    /// A degree-1, five-pole rim edge whose poles ARE the five samples `coaxialCrossSection`
    /// takes, so the only error in those samples is the noise given.
    private struct SampledRim {
        let graph: BRepGraph
        let edge: Edge
        let bounds: (first: Double, last: Double)
        let start: SIMD3<Double>
        let end: SIMD3<Double>
    }

    /// A rim edge whose five poles are the five points `coaxialCrossSection` samples, each off the
    /// circle of radius 5 at height 10 by the given noise.
    ///
    /// A degree-1 (piecewise-linear) 5-pole BSpline with a CLAMPED knot vector, [0, 0.25, 0.5,
    /// 0.75, 1] with multiplicities [2, 1, 1, 1, 2], is the defining shape of a degree-1 B-spline
    /// with simple interior knots: it interpolates every pole exactly at its corresponding knot
    /// parameter. That gives exact, reproducible control over what `coaxialCrossSection` samples
    /// at its own fractions (0, 0.25, 0.5, 0.75, 1.0), no interpolation-parameterization
    /// guesswork the way `Curve3D.interpolate` would need.
    private func makeSampledRim(radiusNoise: [Double], heightNoise: [Double]) throws -> SampledRim {
        let radius = 5.0
        let height = 10.0
        let angles: [Double] = [0.0, Double.pi / 2, Double.pi, 3 * Double.pi / 2, 2 * Double.pi]
        var poles: [SIMD3<Double>] = []
        for i in 0..<5 {
            let r = radius + radiusNoise[i]
            poles.append(SIMD3(r * cos(angles[i]), r * sin(angles[i]), height + heightNoise[i]))
        }
        let curve = try #require(
            Curve3D.bspline(
                poles: poles, knots: [0, 0.25, 0.5, 0.75, 1.0],
                multiplicities: [2, 1, 1, 1, 2], degree: 1),
            "rim curve")
        let edgeShape = try #require(Shape.edgeFromCurve(curve), "rim edge shape")
        let edge = try #require(Edge(edgeShape), "rim edge")
        let bounds = try #require(edge.parameterBounds, "rim bounds")
        let start = try #require(edge.point(at: bounds.first), "rim start")
        let end = try #require(edge.point(at: bounds.last), "rim end")
        let anyShape = try #require(Shape.box(width: 1, height: 1, depth: 1), "box")
        let graph = try #require(BRepGraph(shape: anyShape), "graph")
        return SampledRim(graph: graph, edge: edge, bounds: bounds, start: start, end: end)
    }

    private func isCoaxial(_ rim: SampledRim, edgeTolerance: Double) -> Bool {
        let axis = ShapeAxis(origin: .zero, direction: Self.zAxis, kind: .cylinder)
        return rim.graph.coaxialCrossSection(
            of: rim.edge, bounds: rim.bounds, start: rim.start, end: rim.end, axis: axis,
            edgeTolerance: edgeTolerance)
    }

    @Test(
        "coaxialCrossSection accepts sampled height/radius noise within the edge's own measured BRep tolerance, not just the machine-precision floor (#894 finding 2, fifth pass)"
    )
    func coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise() throws {
        // Per-point noise, ~3e-5 in magnitude, comfortably above the old flat 1e-7 floor, and
        // well inside the review's own cited 1e-4-1e-3 post-Boolean/fillet BRep tolerance range,
        // simulating a genuine circular rim that has accumulated real numerical noise. The
        // samples spread by 7e-5 in radius and in height.
        let noisy = try makeSampledRim(
            radiusNoise: [2e-5, -3e-5, 1e-5, -4e-5, 3e-5],
            heightNoise: [3e-5, -2e-5, 4e-5, -3e-5, 1e-5])

        // The measured height/radius spread of this fixture's 5 samples (~7e-5, by construction)
        // must exceed the old flat floor for this test to prove anything, confirmed directly
        // below rather than assumed, per okf/policies/prove-the-test-fails.md.
        #expect(
            !isCoaxial(noisy, edgeTolerance: 0),
            "fixture noise must exceed the machine-precision floor, or this test proves nothing")

        // A realistic measured BRep_Tool::Tolerance for this rim (1e-4, well within the review's
        // own cited range) widens the comparison enough to accept the same noisy points, this is
        // the fix: pre-fix, `coaxialCrossSection` had no `edgeTolerance` parameter at all and
        // always compared against the machine-precision floor alone, so this call would have
        // returned `false` regardless of what tolerance the caller measured.
        #expect(isCoaxial(noisy, edgeTolerance: 1e-4))
        // And the tolerance is a real bound, not a switch: just under the 7e-5 spread it still
        // refuses, so the comparison is made against the number the edge reports.
        #expect(!isCoaxial(noisy, edgeTolerance: 5e-5))
    }

    @Test(
        "coaxialCrossSection needs the height AND the radius to hold, over a floor under the tolerance"
    )
    func coaxialCrossSectionChecksHeightAndRadiusAndKeepsAFloor() throws {
        // Each half of the test is isolated by a rim that fails only that half. They cannot be
        // told apart through a real cylinder or cone edge: every point of an edge on a cylinder
        // is at the cylinder's radius, and on a cone the radius is a function of the height, so
        // a perfect rim would pass both and a bad one fails the height check first.
        let quiet = [0.0, 0.0, 0.0, 0.0, 0.0]
        let wobble = [0.0, 3e-4, 0.0, 3e-4, 0.0]

        // A clean circle passes on the floor alone, with an edge tolerance of 0: the floor
        // exists and a spread of zero is inside it.
        let pristine = try makeSampledRim(radiusNoise: quiet, heightNoise: quiet)
        #expect(isCoaxial(pristine, edgeTolerance: 0), "a clean circle passes on the floor")

        // Height varies by 3e-4 while the radius is exact: refused at 1e-4, accepted at 1e-3.
        let heightOnly = try makeSampledRim(radiusNoise: quiet, heightNoise: wobble)
        #expect(
            !isCoaxial(heightOnly, edgeTolerance: 1e-4), "varying height is not a cross-section")
        #expect(isCoaxial(heightOnly, edgeTolerance: 1e-3), "the edge's own tolerance covers 3e-4")

        // The same for the radius, with the height exact.
        let radiusOnly = try makeSampledRim(radiusNoise: wobble, heightNoise: quiet)
        #expect(
            !isCoaxial(radiusOnly, edgeTolerance: 1e-4), "varying radius is not a cross-section")
        #expect(isCoaxial(radiusOnly, edgeTolerance: 1e-3), "the edge's own tolerance covers 3e-4")
    }

    /// A quarter-cylinder face whose top rim is interpolated through five points that are NOT
    /// evenly spaced in angle, so the samples `coaxialCrossSection` takes fall between the
    /// interpolation points and sit off the true circle by about 2.7e-3.
    ///
    /// Building the face leaves that rim with a BRep tolerance of about 3.2e-3, which covers the
    /// deviation (measured). Every call builds a fresh shape, so a tolerance set on one does not
    /// reach another.
    private func makeInterpolatedRimFace() throws -> Shape {
        let radius = 5.0
        let height = 10.0
        func rimPoint(_ degrees: Double, _ z: Double) -> SIMD3<Double> {
            let a = degrees * Double.pi / 180
            return SIMD3(radius * cos(a), radius * sin(a), z)
        }
        let angles: [Double] = [0, 15, 45, 75, 90]
        var topPoints: [SIMD3<Double>] = []
        for angle in angles {
            topPoints.append(rimPoint(angle, height))
        }
        let surface = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius), "surface")
        let topCurve = try #require(Curve3D.interpolate(points: topPoints), "interpolated rim")
        let topShape = try #require(Shape.edgeFromCurve(topCurve), "rim shape")
        let topEdge = try #require(Edge(topShape), "rim edge")
        let seam0 = try #require(Wire.line(from: rimPoint(0, 0), to: rimPoint(0, height)), "seam 0")
        let seam0Edge = try #require(seam0.edges().first, "seam 0 edge")
        let seam1 = try #require(
            Wire.line(from: rimPoint(90, height), to: rimPoint(90, 0)), "seam 1")
        let seam1Edge = try #require(seam1.edges().first, "seam 1 edge")
        let botCurve = try #require(
            Curve3D.arcOfCircle(
                start: rimPoint(90, 0), interior: rimPoint(45, 0), end: rimPoint(0, 0)),
            "bottom arc")
        let botShape = try #require(Shape.edgeFromCurve(botCurve), "bottom shape")
        let botEdge = try #require(Edge(botShape), "bottom edge")
        let wire = try #require(
            Wire.wireFromEdges([seam0Edge, topEdge, seam1Edge, botEdge]), "wire")
        return try #require(Shape.face(from: surface, boundary: wire), "face")
    }

    @Test(
        "alongEdge decides a rim is circular against the edge's own BRep tolerance (#894 finding 2, fifth pass)"
    )
    func alongEdgeAcceptsRimWithinItsOwnMeasuredTolerance() throws {
        let radius = 5.0
        let height = 10.0
        let rimStart = SIMD3<Double>(radius, 0, height)
        let rimEnd = SIMD3<Double>(0, radius, height)

        // As built: the edge carries the tolerance the face building gave it.
        let natural = try makeInterpolatedRimFace()
        let graph = try #require(BRepGraph(shape: natural), "graph of the face")
        let rimIndex = try #require(
            firstEdgeIndex(in: graph, curveType: .bsplineCurve), "the interpolated rim edge")
        let rimShape = try #require(
            graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: rimIndex), "rim shape")
        let rim = try #require(rimShape.edges().first, "rim edge")
        let bounds = try #require(rim.parameterBounds, "rim bounds")
        var radii: [Double] = []
        for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let sample = try #require(
                rim.point(at: bounds.first + (bounds.last - bounds.first) * fraction), "sample")
            radii.append(simd_length(SIMD3<Double>(sample.x, sample.y, 0)))
        }
        let spread = (radii.max() ?? 0) - (radii.min() ?? 0)
        let naturalTolerance = graph.edgeTolerance(rimIndex)
        // The premise: the samples are well off the machine floor, and the edge's own tolerance
        // is what covers them.
        #expect(spread > 1e-3, "the samples must deviate beyond any floor, got \(spread)")
        #expect(
            naturalTolerance > spread, "the edge's tolerance \(naturalTolerance) covers \(spread)")

        // So the rim is accepted as a circular cross-section of the wall: the axis, on the
        // centerline at the rim's height, running the way the rim turns (+Z, counterclockwise).
        let onAxis = SIMD3<Double>(0, 0, height)
        let ax = try alongEdge(graph, rimIndex).get()
        #expect(isClose(ax.origin, onAxis), "origin \(ax.origin)")
        #expect(isClose(ax.direction, Self.zAxis), "direction \(ax.direction)")

        // The same geometry with the tolerance lowered below the deviation is refused: it is the
        // edge's tolerance that decided, so what is left is the chord from where the arc starts
        // to where it ends.
        let tight = try makeInterpolatedRimFace()
        tight.setTolerance(1e-4)
        let tightGraph = try #require(BRepGraph(shape: tight), "graph of the tightened face")
        let tightIndex = try #require(
            firstEdgeIndex(in: tightGraph, curveType: .bsplineCurve), "the rim edge")
        #expect(tightGraph.edgeTolerance(tightIndex) < spread, "tolerance 1e-4 is below \(spread)")
        let chord = try alongEdge(tightGraph, tightIndex).get()
        #expect(isClose(chord.origin, rimStart, 1e-6), "chord origin \(chord.origin)")
        let chordDirection = simd_normalize(rimEnd - rimStart)
        #expect(
            isClose(chord.direction, chordDirection, 1e-6), "chord direction \(chord.direction)")
    }

    @Test(
        "axesAgree compares the direction and the line separately, within a tight tolerance (#894 finding 1)"
    )
    func axesAgreeComparesDirectionAndLineSeparately() throws {
        let box = try #require(Shape.box(width: 1, height: 1, depth: 1), "box")
        let graph = try #require(BRepGraph(shape: box), "graph of a box")
        func axis(_ origin: SIMD3<Double>, _ direction: SIMD3<Double>) -> ShapeAxis {
            ShapeAxis(origin: origin, direction: direction, kind: .cylinder)
        }
        let reference = axis(SIMD3(0, 0, 0), SIMD3(0, 0, 1))

        // One line, written three ways: itself, pointing the other way, and with its origin
        // slid along it.
        #expect(graph.axesAgree(reference, reference))
        #expect(graph.axesAgree(reference, axis(SIMD3(0, 0, 0), SIMD3(0, 0, -1))), "anti-parallel")
        #expect(
            graph.axesAgree(reference, axis(SIMD3(0, 0, 7), SIMD3(0, 0, 1))), "origin slid along")

        // Not the same line, each caught by one guard alone. Parallel but a unit to the side is a
        // distinct bore of the same diameter (the origin guard). The same origin with another
        // direction is a different axis through the same point (the direction guard), which the
        // origin guard cannot see.
        #expect(!graph.axesAgree(reference, axis(SIMD3(1, 0, 0), SIMD3(0, 0, 1))), "distinct bore")
        #expect(!graph.axesAgree(reference, axis(SIMD3(0, 0, 0), SIMD3(1, 0, 0))), "crossing axis")

        // The direction tolerance is a cosine tolerance of 1e-12, which admits about 1.4e-6 rad:
        // a milliradian is refused and a hundredth of a microradian is not.
        let tilted = SIMD3<Double>(sin(1e-3), 0, cos(1e-3))
        #expect(!graph.axesAgree(reference, axis(SIMD3(0, 0, 0), tilted)), "a milliradian apart")
        let nearlyParallel = SIMD3<Double>(sin(1e-8), 0, cos(1e-8))
        #expect(graph.axesAgree(reference, axis(SIMD3(0, 0, 0), nearlyParallel)), "1e-8 rad apart")
    }
}
