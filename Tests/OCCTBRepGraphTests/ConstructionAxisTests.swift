import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.142 ConstructionAxis resolution")
struct ConstructionAxisTests {
    /// Finds the index of the first edge in `graph` whose curve type is `curveType`, or nil if
    /// none exists. Shared by the two "straight seam reparameterized as a BSpline" fixtures below
    /// (cylinder and cone), which each searched for the synthetic BSpline seam edge with a
    /// byte-identical inline loop (#1252).
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

    @Test("alongEdge produces edge start + unit direction")
    func alongEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let edge = TopologyRef.literal(.init(kind: .edge, index: 0))
        switch graph.resolve(ConstructionAxis.alongEdge(edge)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure: Issue.record("alongEdge failed")
        }
    }

    @Test("alongEdge on a full-circle cylindrical rim resolves to the true rotation axis (#883)")
    func alongEdgeCylindricalRimUsesRevolutionAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("cylinder/graph nil")
            return
        }
        // A rim is a full circle: start == end, so the old secant-of-endpoints computation
        // was always the zero vector here, this is failure mode 1 from #883.
        guard let rim = cyl.edges().first(where: { $0.curveType == .circle }),
            let rimBounds = rim.parameterBounds,
            let rimPoint = rim.point(at: rimBounds.first),
            let rimShape = Shape.fromEdge(rim),
            let node = graph.findNode(for: rimShape), node.kind == .edge
        else {
            Issue.record("no circular rim edge found")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            #expect(abs(abs(ax.direction.z) - 1.0) < 1e-6)
            // #894 finding 2: the origin must stay edge-local (on the axis, at the rim's own
            // height), not teleport to the cylinder surface's own placement origin, which would
            // report (0, 0, 0) regardless of which rim (top or bottom) this is.
            #expect(abs(ax.origin.x) < 1e-6)
            #expect(abs(ax.origin.y) < 1e-6)
            #expect(abs(ax.origin.z - rimPoint.z) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (revolution axis), got \(e)")
        }
    }

    @Test(
        "alongEdge on a partial cylindrical arc resolves to the axis, not the endpoint chord (#883)"
    )
    func alongEdgePartialCylinderUsesAxisNotChord() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10, angle: .pi / 2),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("partial cylinder/graph nil")
            return
        }
        // A 90-degree arc's own endpoint chord lies in the XY plane (z ~ 0), this is failure
        // mode 2 from #883: a plausible-looking but wrong direction. The true rotation axis is
        // parallel to Z.
        guard let arc = cyl.edges().first(where: { $0.curveType == .circle && !$0.isClosed3D }),
            let arcBounds = arc.parameterBounds,
            let arcPoint = arc.point(at: arcBounds.first),
            let arcShape = Shape.fromEdge(arc),
            let node = graph.findNode(for: arcShape), node.kind == .edge
        else {
            Issue.record("no partial arc edge found")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            #expect(abs(abs(ax.direction.z) - 1.0) < 1e-6)
            // #894 finding 2: the origin must stay edge-local (on the axis, at the arc's own
            // height), not the surface's own placement origin (0, 0, 0) regardless of which end
            // of the cylinder this arc sits at.
            #expect(abs(ax.origin.x) < 1e-6)
            #expect(abs(ax.origin.y) < 1e-6)
            #expect(abs(ax.origin.z - arcPoint.z) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (revolution axis), got \(e)")
        }
    }

    @Test(
        "alongEdge on a standalone closed circular wire (no adjacent face) fails with degenerate (#887)"
    )
    func alongEdgeStandaloneCircleNoAdjacentFaceDegenerate() {
        // A full circle with no adjacent face at all: revolutionAxis(ofEdgeAt:) finds nothing
        // to redirect to (faces(of:) is empty), so this falls through to the endpoint-secant
        // path, where start == end for a closed curve, the zero-length branch that #887 found
        // had no coverage at all.
        guard let wire = Wire.circle(radius: 5),
            let wireShape = Shape.fromWire(wire),
            let graph = BRepGraph(shape: wireShape)
        else {
            Issue.record("wire/shape/graph nil")
            return
        }
        guard let edge = wireShape.edges().first,
            let edgeShape = Shape.fromEdge(edge),
            let node = graph.findNode(for: edgeShape), node.kind == .edge
        else {
            Issue.record("no edge found")
            return
        }
        #expect(graph.faces(of: node.index).isEmpty)
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test(
        "alongEdge on a T-branch between two non-coaxial cylinders falls back to the chord, not whichever face's axis sorts first (#894 finding 1)"
    )
    func alongEdgeBranchWithDisagreeingAxesFallsBackToChord() {
        // Two non-coaxial cylinders fused at a T-junction: the intersection curve is adjacent to
        // both cylindrical walls, and the two candidate axes do not agree, exactly the branch
        // case finding 1 covers. Pre-fix, `revolutionAxis(ofEdgeAt:)` returned whichever face's
        // axis happened to sort first in `faces(of:)`, with no check that a second, disagreeing
        // candidate existed.
        guard
            let mainCyl = Shape.cylinder(
                at: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1), radius: 5, height: 20),
            let branchCyl = Shape.cylinder(
                at: SIMD3(-10, -10, -2), direction: simd_normalize(SIMD3(1, 1, 0.3)),
                radius: 2.5, height: 20),
            let fused = mainCyl.union(branchCyl),
            let graph = BRepGraph(shape: fused)
        else {
            Issue.record("T-branch fixture build failed")
            return
        }

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
        var target: (edgeIndex: Int, axisA: ShapeAxis, axisB: ShapeAxis)?
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

            target = (edgeIndex, candidates[0], candidates[1])
            break
        }
        guard let target else {
            Issue.record("no usable branch edge found in T-branch fixture")
            return
        }

        // Exercise the real production decision directly, not just its downstream effect: the
        // disagreeing candidates found above must make `revolutionAxis(ofEdgeAt:)` itself decline
        // (#894 finding 5, second pass), the assertions below on `resolve(.alongEdge(...))` then
        // confirm the caller-visible consequence of that decision.
        #expect(graph.revolutionAxis(ofEdgeAt: target.edgeIndex) == nil)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: target.edgeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Must NOT silently match either candidate face's axis (the pre-fix bug), must fall
            // back to the edge's own chord instead.
            #expect(abs(simd_dot(ax.direction, simd_normalize(target.axisA.direction))) < 0.9)
            #expect(abs(simd_dot(ax.direction, simd_normalize(target.axisB.direction))) < 0.9)
        case .failure(let e):
            Issue.record("expected success (chord fallback), got \(e)")
        }
    }

    @Test(
        "alongEdge keeps the origin edge-local, not the adjacent surface's own placement origin (#894 finding 2)"
    )
    func alongEdgeCylindricalRimOriginStaysNearRimNotSurfaceBase() {
        // A rim near the TOP of a tall cylinder whose base sits at z=0, the review's own example
        // of a ~500mm teleport. axis.origin for the wall face is the surface's own placement
        // origin (0, 0, 0); if that leaked through as the resolved origin, a materialized axis
        // marker or a sketch plane built `throughAxis` would land ~500mm from the rim the caller
        // actually selected.
        guard let cyl = Shape.cylinder(radius: 5, height: 500),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("tall cylinder/graph nil")
            return
        }
        guard
            let topRim = cyl.edges().first(where: { edge in
                guard edge.curveType == .circle, let bounds = edge.parameterBounds,
                    let p = edge.point(at: bounds.first)
                else { return false }
                return abs(p.z - 500) < 1e-6
            }),
            let rimShape = Shape.fromEdge(topRim),
            let node = graph.findNode(for: rimShape), node.kind == .edge
        else {
            Issue.record("no top rim edge found")
            return
        }
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            #expect(abs(ax.origin.x) < 1e-6)
            #expect(abs(ax.origin.y) < 1e-6)
            #expect(abs(ax.origin.z - 500) < 1e-6)
        case .failure(let e):
            Issue.record("expected success, got \(e)")
        }
    }

    @Test(
        "alongEdge on a geometrically-straight seam reparameterized as a BSpline keeps the chord, not the axis (#894 finding 3)"
    )
    func alongEdgeStraightSeamReparameterizedAsBSplineKeepsChord() {
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

        guard let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let seamCurve = Curve3D.interpolate(points: [p0bot, p0mid, p0top]),
            let seamEdgeShape = Shape.edgeFromCurve(seamCurve),
            let seamEdge = Edge(seamEdgeShape),
            let otherSideWire = Wire.line(from: p1top, to: p1bot),
            let otherSideEdge = otherSideWire.edges().first,
            let topArcCurve = Curve3D.arcOfCircle(
                start: p0top,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 10.0),
                end: p1top),
            let topArcShape = Shape.edgeFromCurve(topArcCurve),
            let topArcEdge = Edge(topArcShape),
            let botArcCurve = Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0),
                end: p0bot),
            let botArcShape = Shape.edgeFromCurve(botArcCurve),
            let botArcEdge = Edge(botArcShape),
            let wire = Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("synthetic straight-seam fixture build failed")
            return
        }

        // Confirm the fixture matches the intended scenario, then find that edge by its (unique)
        // BSpline curveType rather than assuming an index.
        guard let seamNodeIndex = firstEdgeIndex(in: graph, curveType: .bsplineCurve) else {
            Issue.record("no BSpline-curveType edge found in fixture")
            return
        }

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: seamNodeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Direction along the seam (Z), true either way, since axis and chord happen to
            // agree here. The origin is what distinguishes "kept the chord" from "redirected to
            // the axis": redirecting would project onto the cylinder's own axis line (x=y=0),
            // which for this seam happens to yield (0, 0, 0) too, so the discriminating check is
            // that the origin stays at the edge's own (x, y) position, not on the centerline.
            #expect(abs(abs(ax.direction.z) - 1.0) < 1e-6)
            #expect(simd_distance(ax.origin, p0bot) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (chord kept for straight seam), got \(e)")
        }
    }

    @Test(
        "alongEdge on an elliptical rim from an oblique cylinder cut does not silently return the cylinder's centerline (#894 finding 1, third pass)"
    )
    func alongEdgeEllipticalRimDoesNotSilentlyReturnCenterline() {
        // A cylinder intersected with a large box tilted about Y by `theta`: the box's near face
        // becomes an oblique cutting plane through the cylinder's mid-height, producing a closed
        // elliptical rim (curveType == .ellipse) adjacent to the cylindrical wall. Every point of
        // that rim sits on the wall (radius == cylinder radius everywhere, same as a true circular
        // rim), but its height along the axis varies as you go around it, exactly the case
        // `curveType != .line` alone can't distinguish from a genuine cross-section.
        let radius = 5.0
        let height = 20.0
        let theta = 25.0 * Double.pi / 180
        // Box spans z in [-1000, z0] before rotation; z0 is chosen so the rotated top face
        // passes through (0, 0, 10), the cylinder's own mid-height on its axis, with normal
        // (sin(theta), 0, cos(theta)).
        let z0 = 10.0 * cos(theta)

        guard let cyl = Shape.cylinder(radius: radius, height: height),
            let bigBox = Shape.box(
                origin: SIMD3(-500, -500, -1000), width: 1000, height: 1000, depth: 1000 + z0),
            let tiltedBox = bigBox.rotated(axis: SIMD3(0, 1, 0), angle: theta),
            let cut = cyl.intersection(tiltedBox),
            let graph = BRepGraph(shape: cut)
        else {
            Issue.record("oblique-cut cylinder fixture build failed")
            return
        }
        guard let ellipse = cut.edges().first(where: { $0.curveType == .ellipse }),
            let ellipseShape = Shape.fromEdge(ellipse),
            let node = graph.findNode(for: ellipseShape), node.kind == .edge
        else {
            Issue.record("no elliptical rim edge found in oblique-cut fixture")
            return
        }
        // Confirm the fixture matches finding 1's premise: exactly one adjacent face contributes
        // a cylinder/cone axis candidate (the trimmed wall), same as a genuine circular rim, so
        // `revolutionAxis` has nothing to disagree with and would return it unconditionally
        // without the geometric cross-section check this finding adds.
        let cylConeFaceCount = graph.faces(of: node.index).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cylinder || axis.kind == .cone
        }.count
        #expect(cylConeFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: node.index))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Must not be the cylinder's centerline (direction parallel to Z AND origin on the
            // x=y=0 axis), a fallback to the (near-zero, closed-curve) chord landing anywhere
            // else is fine; only silently matching the centerline is the bug.
            let onCenterlineDirection = abs(abs(ax.direction.z) - 1.0) < 1e-6
            let onCenterlineOrigin = abs(ax.origin.x) < 1e-6 && abs(ax.origin.y) < 1e-6
            #expect(!(onCenterlineDirection && onCenterlineOrigin))
        case .failure(.degenerate):
            ()  // failing cleanly is fine too: a full ellipse's own chord is ~0, same as a full
        // circle's would be without the (correctly declined) axis redirect.
        case .failure(let e):
            Issue.record(
                "expected success (chord fallback) or a clean .degenerate failure, got \(e)")
        }
    }

    @Test(
        "alongEdge on a genuinely near-zero-length edge next to a clean cylindrical face still reports degenerate (#894 finding 2, third pass)"
    )
    func alongEdgeGenuinelyDegenerateEdgeNextToCleanCylinderStillDegenerate() {
        // A partial cylinder with an astronomically tiny angular extent (1e-10 rad): its two rim
        // arcs (curveType == .circle, non-linear, so the OLD `curveType != .line` gate alone
        // would have let this reach `revolutionAxis`) measure a true length of 5e-10, genuinely
        // near-zero and below this file's degeneracy epsilon, while still bounding one clean
        // cylindrical wall face, the shape finding 2 needs: `revolutionAxis` finds an
        // unambiguous candidate axis for an edge that is itself malformed, which used to let it
        // skip the degeneracy check entirely.
        guard let cyl = Shape.cylinder(radius: 5, height: 10, angle: 1e-10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("degenerate-sliver fixture build failed")
            return
        }

        // Find a tiny rim arc by measured length rather than assuming an index.
        var tinyNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first
            else { continue }
            if edge.length < 1e-9, edge.curveType != .line {
                tinyNodeIndex = edgeIndex
                break
            }
        }
        guard let tinyNodeIndex else {
            Issue.record("no near-zero-length non-line edge found in sliver fixture")
            return
        }
        // Confirm the fixture matches finding 2's premise: exactly one adjacent face contributes
        // a cylinder/cone axis candidate, same as a legitimate rim, `revolutionAxis` has nothing
        // to disagree with and would return it unconditionally without the fix.
        let cylConeFaceCount = graph.faces(of: tinyNodeIndex).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cylinder || axis.kind == .cone
        }.count
        #expect(cylConeFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: tinyNodeIndex))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test(
        "alongEdge on a cone's straight generatrix reparameterized as a BSpline keeps the chord, not the axis (#894 finding 1, second pass)"
    )
    func alongEdgeConeStraightSeamReparameterizedAsBSplineKeepsChord() {
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

        guard
            let surface = Surface.cone(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: bottomRadius, semiAngle: semiAngle),
            let seamCurve = Curve3D.interpolate(points: [p0bot, p0mid, p0top]),
            let seamEdgeShape = Shape.edgeFromCurve(seamCurve),
            let seamEdge = Edge(seamEdgeShape),
            let otherSideWire = Wire.line(from: p1top, to: p1bot),
            let otherSideEdge = otherSideWire.edges().first,
            let topArcCurve = Curve3D.arcOfCircle(
                start: p0top,
                interior: SIMD3(
                    radius(atHeight: 10) * cos(midAngle), radius(atHeight: 10) * sin(midAngle),
                    10.0),
                end: p1top),
            let topArcShape = Shape.edgeFromCurve(topArcCurve),
            let topArcEdge = Edge(topArcShape),
            let botArcCurve = Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(
                    radius(atHeight: 0) * cos(midAngle), radius(atHeight: 0) * sin(midAngle), 0.0),
                end: p0bot),
            let botArcShape = Shape.edgeFromCurve(botArcCurve),
            let botArcEdge = Edge(botArcShape),
            let wire = Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("synthetic cone straight-seam fixture build failed")
            return
        }

        guard let seamNodeIndex = firstEdgeIndex(in: graph, curveType: .bsplineCurve) else {
            Issue.record("no BSpline-curveType edge found in cone fixture")
            return
        }
        // Confirm the fixture matches the premise: the seam edge is adjacent to a cone-kind face
        // (so `revolutionAxis` has a candidate to redirect to at all).
        let coneFaceCount = graph.faces(of: seamNodeIndex).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cone
        }.count
        #expect(coneFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: seamNodeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // The chord and the cone's axis are NOT parallel (nonzero half-angle), unlike the
            // cylinder case, direction alone distinguishes "kept the chord" from "redirected to
            // the axis" here too, so both direction and origin are asserted directly against the
            // seam's own geometry.
            let expectedDirection = simd_normalize(p0top - p0bot)
            #expect(simd_dot(ax.direction, expectedDirection) > 1 - 1e-6)
            #expect(simd_distance(ax.origin, p0bot) < 1e-6)
        case .failure(let e):
            Issue.record("expected success (chord kept for cone straight seam), got \(e)")
        }
    }

    @Test(
        "alongEdge derives its sign from the edge's own start->end order, not the adjacent surface's placement convention (#894 finding 2, second pass)"
    )
    func alongEdgeSignTracksEdgeTopologyNotSurfaceConvention() {
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

        func topArcDirection(from faceShape: Shape) -> SIMD3<Double>? {
            guard let graph = BRepGraph(shape: faceShape) else { return nil }
            var topNodeIndex: Int?
            for edgeIndex in 0..<graph.edgeCount {
                guard
                    let eShape = graph.shape(
                        nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                    let edge = eShape.edges().first,
                    edge.curveType == .circle,
                    let bounds = edge.parameterBounds,
                    let p = edge.point(at: bounds.first)
                else { continue }
                if abs(p.z - height) < 1e-6 {
                    topNodeIndex = edgeIndex
                    break
                }
            }
            guard let topNodeIndex else { return nil }
            let edgeRef = TopologyRef.literal(.init(kind: .edge, index: topNodeIndex))
            guard case .success(let ax) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) else {
                return nil
            }
            return ax.direction
        }

        // Top arc parameterized pA -> pB (bounds.first == pA).
        guard
            let surfaceForward = Surface.cylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let topArcForward = Curve3D.arcOfCircle(start: pA, interior: pMidTop, end: pB),
            let topArcForwardShape = Shape.edgeFromCurve(topArcForward),
            let topArcForwardEdge = Edge(topArcForwardShape),
            let botArcForward = Curve3D.arcOfCircle(start: qB, interior: qMidBot, end: qA),
            let botArcForwardShape = Shape.edgeFromCurve(botArcForward),
            let botArcForwardEdge = Edge(botArcForwardShape),
            let upForwardWire = Wire.line(from: qA, to: pA),
            let upForwardEdge = upForwardWire.edges().first,
            let downForwardWire = Wire.line(from: pB, to: qB),
            let downForwardEdge = downForwardWire.edges().first,
            let wireForward = Wire.wireFromEdges([
                upForwardEdge, topArcForwardEdge, downForwardEdge, botArcForwardEdge,
            ]),
            let faceForward = Shape.face(from: surfaceForward, boundary: wireForward),
            let forward = topArcDirection(from: faceForward)
        else {
            Issue.record("forward-order fixture build/resolve failed")
            return
        }

        // Top arc parameterized pB -> pA (bounds.first == pB), the physically identical rim,
        // opposite parameter order. Every other edge is rebuilt to match (see the wire-fitting
        // sensitivity noted above); this specific combination was confirmed by direct inspection
        // to also build a clean 4-edge wire.
        guard
            let surfaceReversed = Surface.cylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let topArcReversed = Curve3D.arcOfCircle(start: pB, interior: pMidTop, end: pA),
            let topArcReversedShape = Shape.edgeFromCurve(topArcReversed),
            let topArcReversedEdge = Edge(topArcReversedShape),
            let botArcReversed = Curve3D.arcOfCircle(start: qB, interior: qMidBot, end: qA),
            let botArcReversedShape = Shape.edgeFromCurve(botArcReversed),
            let botArcReversedEdge = Edge(botArcReversedShape),
            let eReversed1Wire = Wire.line(from: pB, to: qB),
            let eReversed1 = eReversed1Wire.edges().first,
            let eReversed2Wire = Wire.line(from: qA, to: pA),
            let eReversed2 = eReversed2Wire.edges().first,
            let wireReversed = Wire.wireFromEdges([
                eReversed1, topArcReversedEdge, eReversed2, botArcReversedEdge,
            ]),
            let faceReversed = Shape.face(from: surfaceReversed, boundary: wireReversed),
            let reversed = topArcDirection(from: faceReversed)
        else {
            Issue.record("reversed-order fixture build/resolve failed")
            return
        }

        // Same physical axis either way.
        #expect(abs(abs(forward.z) - 1.0) < 1e-6)
        #expect(abs(abs(reversed.z) - 1.0) < 1e-6)
        // Reversing which endpoint is `first` must flip the resolved sign.
        #expect(simd_dot(forward, reversed) < 0)
    }

    @Test(
        "alongEdge on a helical thread edge does not silently return the cylinder's centerline (#894 finding 3, second pass)"
    )
    func alongEdgeHelicalEdgeDoesNotSilentlyReturnCenterline() {
        // A helix's two-point secant can land nearly parallel to the cylinder's axis purely from
        // the sweep angle, the old chord-parallel-to-axis check (removed by the third pass's
        // `coaxialCrossSection` rewrite) could misfire on this. A full single turn (parameter
        // range 0...2*pi) puts start and end at the SAME angular position, `pitch` apart in
        // height, the secant is then EXACTLY axis-parallel, the strongest form of the old false
        // positive. `coaxialCrossSection`'s height-constancy check has no such blind spot:
        // sampling interior points along a genuine helix shows height varying continuously across
        // the whole span, unlike a true perpendicular cross-section.
        let radius = 5.0
        let pitch = 10.0
        guard
            let helixBuild = Helix.build(
                origin: .zero, direction: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
                parameterRange: 0...(2 * Double.pi), pitch: pitch, radius: radius),
            let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let helixEdgeShape = Shape.edgeFromCurve(helixBuild.curve),
            let helixEdge = Edge(helixEdgeShape),
            let closeWire = Wire.line(from: SIMD3(radius, 0, pitch), to: SIMD3(radius, 0, 0)),
            let closeEdge = closeWire.edges().first,
            let wire = Wire.wireFromEdges([helixEdge, closeEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("helical-edge fixture build failed")
            return
        }

        var helixNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first,
                edge.curveType != .line
            else { continue }
            helixNodeIndex = edgeIndex
            break
        }
        guard let helixNodeIndex else {
            Issue.record("no non-line edge found in helical fixture")
            return
        }
        // Confirm the fixture matches the premise: adjacent to exactly one cylinder-kind face,
        // same as a genuine rim, `revolutionAxis` has nothing to disagree with, so only
        // `coaxialCrossSection`'s own height check can decline the redirect.
        let cylFaceCount = graph.faces(of: helixNodeIndex).filter { faceIndex in
            guard
                let faceShape = graph.shape(
                    nodeKind: BRepGraph.NodeKind.face, nodeIndex: faceIndex),
                let face = faceShape.faces().first, let axis = face.primaryAxis
            else { return false }
            return axis.kind == .cylinder
        }.count
        #expect(cylFaceCount == 1)

        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: helixNodeIndex))
        switch graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        case .success(let ax):
            // Must not teleport to the centerline (x = y = 0): the fallback secant's origin is
            // the helix's own start point, still on the cylinder wall, the same discriminator
            // the straight-seam test above uses, since the secant's DIRECTION happens to coincide
            // with the axis direction here too (chosen deliberately, matching the old false
            // positive's strongest form).
            let radialDistance = (ax.origin.x * ax.origin.x + ax.origin.y * ax.origin.y)
                .squareRoot()
            #expect(radialDistance > radius - 1e-6)
        case .failure(let e):
            Issue.record("expected success (chord fallback for helical edge), got \(e)")
        }
    }

    @Test("throughPoints on coincident vertices fails with degenerate")
    func coincidentPointsDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let v = TopologyRef.literal(.init(kind: .vertex, index: 0))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.throughPoints(v, v)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test("intersectionOfPlanes on parallel planes fails with degenerate")
    func parallelIntersectionDegenerate() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let a = ConstructionPlane.absolute(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let b = ConstructionPlane.absolute(origin: SIMD3(0, 0, 5), normal: SIMD3(0, 0, 1))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.intersectionOfPlanes(a, b)) {
        } else {
            Issue.record("expected degenerate")
        }
    }

    @Test(
        "normalToFace on a cylinder returns the rotation axis, not the local radial normal (#882)")
    func normalToFaceCylinderPrimaryAxis() {
        // The doc promises the cylinder's own rotation axis (here unit Z). Before
        // #882, normalToFace returned the UV-midpoint radial normal instead,
        // which lies in the XY plane and has zero Z component.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 1))
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            #expect(abs(ax.direction.z) > 0.99)
        case .failure: Issue.record("normalToFace failed")
        }
    }

    @Test(
        "normalToFace on a cylinder anchors the returned axis on the true centerline, not the off-axis vertex it was asked at (PR #897 review, third pass)"
    )
    func normalToFaceCylinderOriginOnAxis() {
        // Vertex 1 sits ON the lateral surface, radius 5 from the true centerline (the Z
        // axis, since Shape.cylinder is centered on it). Before this fix, normalToFace's
        // returned origin was always the raw, off-axis vertex position -- pairing a correct
        // axis DIRECTION with a WRONG axis LOCATION, a line parallel to, but offset by the
        // full radius from, the true rotation axis.
        guard let cyl = Shape.cylinder(radius: 5, height: 10),
            let graph = BRepGraph(shape: cyl)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 1))
        let rawVertex = graph.vertexPoint(1)
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            // The origin must lie ON the true centerline (radial distance 0 from the Z
            // axis), not at the vertex's own radius-5 position.
            let radialDistance = (ax.origin.x * ax.origin.x + ax.origin.y * ax.origin.y)
                .squareRoot()
            #expect(radialDistance < 1e-6)
            // Kept edge-local (projected at the requested vertex's own height along the
            // axis), not snapped to the surface's own placement origin elsewhere on the axis.
            #expect(abs(ax.origin.z - rawVertex.z) < 1e-6)
            #expect(abs(ax.direction.z) > 0.99)
        case .failure(let e): Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test(
        "normalToFace on a torus also anchors the returned axis on the true centerline, not the vertex's own far-off-axis position (PR #897 review, third pass)"
    )
    func normalToFaceTorusOriginOnAxis() {
        // A torus's single seam vertex sits at (majorRadius + minorRadius) from the true
        // centerline -- 25 units here, the widest point on the whole surface -- so this is
        // the most extreme case of the same bug the cylinder test above covers, and the only
        // fixture in this suite that exercises the axis-projection formula for a kind other
        // than `.cylinder` (`.cone`/`.torus`/`.revolution` share the identical code path, but
        // only `.cylinder` had a dedicated origin test before this one).
        guard let torus = Shape.torus(majorRadius: 20, minorRadius: 5),
            let graph = BRepGraph(shape: torus)
        else {
            Issue.record("setup")
            return
        }
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let axis = face.primaryAxis, axis.kind == .torus
        else {
            Issue.record("fixture is not a toroidal face")
            return
        }
        guard graph.vertexCount > 0 else {
            Issue.record("torus fixture has no vertex")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 0))
        let rawVertex = graph.vertexPoint(0)
        let axisDirection = simd_normalize(axis.direction)
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            // The origin must lie ON the true centerline, not at the vertex's own
            // far-off-axis position (radius 25 here).
            let toOrigin = ax.origin - axis.origin
            let radial = toOrigin - simd_dot(toOrigin, axisDirection) * axisDirection
            #expect(simd_length(radial) < 1e-6)
            // Kept edge-local: projected at the requested vertex's own height along the
            // axis, not snapped to the surface's own placement origin.
            let expectedHeight = simd_dot(
                SIMD3(rawVertex.x, rawVertex.y, rawVertex.z) - axis.origin, axisDirection)
            let actualHeight = simd_dot(toOrigin, axisDirection)
            #expect(abs(actualHeight - expectedHeight) < 1e-6)
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure(let e): Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test("normalToFace on a planar face still returns the face normal")
    func normalToFacePlaneFallback() {
        // Planes have no primary axis, so normalToFace must fall back to the
        // UV-midpoint surface normal, the pre-#882 behavior, still correct here.
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let graph = BRepGraph(shape: box)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 0))
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
        case .failure: Issue.record("normalToFace failed")
        }
    }

    @Test(
        "normalToFace on an extrusion-surface face falls back to the UV-midpoint normal, not the sweep direction (PR #897 review)"
    )
    func normalToFaceExtrusionFallsBackToNormal() {
        // Geom_SurfaceOfLinearExtrusion's primaryAxis.direction is the SWEEP direction
        // (tangent to the surface), not a normal, unlike cylinder/cone/sphere/torus/
        // revolution, where primaryAxis.direction genuinely is a rotation axis. A
        // straight-line profile (along X) extruded along Z produces a planar surface
        // whose true normal (Y) is perpendicular to both the profile and the sweep
        // direction; before this fix, normalToFace returned the sweep direction
        // (Z) unconditionally whenever primaryAxis was non-nil.
        guard let line = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
            let surface = Surface.extrusion(profile: line, direction: SIMD3(0, 0, 1)),
            let extrudedFace = Shape.face(from: surface, uRange: 0...10, vRange: 0...10),
            let graph = BRepGraph(shape: extrudedFace)
        else {
            Issue.record("setup")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: 0))

        // Sanity: this fixture really does have an extrusion-kind primaryAxis along
        // the sweep direction, so the test is exercising the branch it claims to.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let axis = face.primaryAxis, axis.kind == .extrusion
        else {
            Issue.record("fixture is not an extrusion-surface face")
            return
        }
        #expect(abs(axis.direction.z) > 0.99, "sweep direction should be along Z")

        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
            // The true surface normal is perpendicular to the sweep direction (Z);
            // the pre-fix bug returned the sweep direction itself here.
            #expect(abs(ax.direction.z) < 0.01)
        case .failure(let e): Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test(
        "normalToFace on a spherical face falls back to the UV-midpoint normal, not the arbitrary pole axis (PR #897 review, 3rd pass)"
    )
    func normalToFaceSphereFallsBackToNormal() {
        // gp_Sphere::Position().Direction() (what Face.primaryAxis reports for a
        // sphere) is just the arbitrary construction-frame pole -- a sphere is
        // symmetric about every axis through its center, so unlike
        // cylinder/cone/torus/revolution it has no intrinsic rotation axis at all.
        // Before this fix, normalToFace returned that same fixed (0,0,1) pole
        // direction for every vertex on the sphere, off by 90 degrees from the true
        // local normal at the equator.
        let radius = 5.0
        guard let sph = Shape.sphere(radius: radius),
            let graph = BRepGraph(shape: sph)
        else {
            Issue.record("graph nil")
            return
        }
        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))

        // Sanity: this fixture really does have a sphere-kind primaryAxis, so the
        // test is exercising the branch it claims to.
        guard let face = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first,
            let axis = face.primaryAxis, axis.kind == .sphere
        else {
            Issue.record("fixture is not a spherical face")
            return
        }
        let poleDirection = simd_normalize(axis.direction)

        // Find the two real pole vertices by position, not by assuming fixed indices 0/1 --
        // vertex enumeration order isn't guaranteed stable across an OCCT kernel rebuild or
        // platform (CLAUDE.md Test Conventions; #897 review, second xhigh pass, finding 4) --
        // matching `tangentToFaceConeApexFallsBackToNormal`'s own by-position search a few
        // hundred lines above.
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
        guard poleIndices.count == 2 else {
            Issue.record("expected exactly 2 pole vertices, found \(poleIndices.count)")
            return
        }
        // The origin and direction must come from the SAME location -- the UV midpoint --
        // not the raw, off-face pole vertex paired with a normal sampled elsewhere (#897
        // review, third pass, finding 2).
        guard let (expectedFallbackPoint, expectedFallbackNormal) = face.uvMidpointSample() else {
            Issue.record("uvMidpointSample unavailable")
            return
        }

        // Checked at both poles to show the exclusion holds regardless of which vertex is asked.
        for vertexIndex in poleIndices {
            let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: vertexIndex))
            switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
            case .success(let ax):
                #expect(abs(simd_length(ax.direction) - 1.0) < 1e-6)
                // The old, broken code returned the fixed pole axis unconditionally;
                // the fallback UV-midpoint normal (at the sphere's equator) is
                // nearly perpendicular to it instead.
                #expect(abs(simd_dot(ax.direction, poleDirection)) < 0.1)
                #expect(simd_length(ax.origin - expectedFallbackPoint) < 1e-6)
                #expect(
                    simd_length(
                        simd_normalize(ax.direction) - simd_normalize(expectedFallbackNormal))
                        < 1e-6)
            case .failure(let e):
                Issue.record("normalToFace failed at vertex \(vertexIndex): \(e)")
            }
        }
    }

    @Test(
        "normalToFace on a free-form face is point-aware, not a fixed UV-midpoint normal (PR #897 review, finding 4)"
    )
    func normalToFaceFreeFormVariesWithPoint() {
        // A non-planar (saddle / hyperbolic-paraboloid) bilinear Bezier patch: doubly ruled,
        // genuinely curved, and has NO primaryAxis at all (only cylinder/cone/torus/sphere/
        // revolution/extrusion surfaces do) -- its true local normal varies substantially
        // across the surface. The 4 corner poles are non-coplanar (p11 != p01 + p10 - p00),
        // which is what makes this a genuine saddle rather than a degenerate plane.
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 3, 3)],
            [SIMD3(3, 0, 3), SIMD3(3, 3, 0)],
        ]
        guard let surface = Surface.bezier(poles: poles),
            let face = Shape.face(from: surface, uBounds: 0...1, vBounds: 0...1),
            let graph = BRepGraph(shape: face)
        else {
            Issue.record("setup")
            return
        }

        // Sanity: this fixture really has no primaryAxis, so the test exercises the no-axis
        // fallback branch it claims to.
        guard let occFace = graph.shape(nodeKind: .face, nodeIndex: 0)?.faces().first else {
            Issue.record("face0 unavailable")
            return
        }
        #expect(occFace.primaryAxis == nil, "fixture should have no primary axis")

        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        var directions: [SIMD3<Double>] = []
        for vertexIndex in 0..<graph.vertexCount {
            let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: vertexIndex))
            if case .success(let ax) = graph.resolve(
                ConstructionAxis.normalToFace(face: faceRef, at: vertexRef))
            {
                directions.append(simd_normalize(ax.direction))
            }
        }
        guard directions.count >= 2 else {
            Issue.record("need at least 2 resolved vertices")
            return
        }
        // Before this fix, every vertex answered the SAME fixed UV-midpoint normal regardless
        // of `at`; this saddle's corners have genuinely different local normals.
        let minDot = directions.dropFirst().reduce(1.0) { min($0, simd_dot(directions[0], $1)) }
        #expect(minDot < 0.99, "normalToFace should vary across a genuinely curved free-form face")
    }

    @Test(
        "normalToFace: the returned origin is the actual on-face point the direction was evaluated at, not `at`'s raw position, when `at` doesn't lie on `face` (PR #897 review, second xhigh pass, finding 2)"
    )
    func normalToFaceOriginIsOnFaceNotRawPoint() {
        // Same saddle fixture as normalToFaceFreeFormVariesWithPoint above (no primaryAxis, so
        // this exercises resolveFaceAxisDirection's point-aware fallback branch), but `at` is a
        // vertex from a SEPARATE box shape entirely -- the same "genuine misuse" pattern
        // tangentToFaceOriginIsOnFaceNotRawPoint already uses for tangentToFace.
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 3, 3)],
            [SIMD3(3, 0, 3), SIMD3(3, 3, 0)],
        ]
        guard let surface = Surface.bezier(poles: poles),
            let saddleFace = Shape.face(from: surface, uBounds: 0...1, vBounds: 0...1),
            let box = Shape.box(width: 10, height: 10, depth: 10),
            let compound = Shape.compound([saddleFace, box]),
            let graph = BRepGraph(shape: compound)
        else {
            Issue.record("setup")
            return
        }

        // Saddle added first -- confirm face 0 of the compound really is the saddle, not the
        // box, and really has no primaryAxis.
        guard let faceShape = graph.shape(nodeKind: .face, nodeIndex: 0),
            let saddle = faceShape.faces().first, saddle.primaryAxis == nil
        else {
            Issue.record("face 0 of the compound is not the no-axis saddle")
            return
        }

        // A vertex on the BOX, far from the saddle patch -- find one whose projection onto the
        // saddle is not itself.
        var offFaceVertexIndex: Int?
        for vertexIndex in 0..<graph.vertexCount {
            let raw = graph.vertexPoint(vertexIndex)
            let p = SIMD3(raw.x, raw.y, raw.z)
            guard simd_length(p) > 1.0 else { continue }  // skip the saddle's own corners near 0
            guard let projection = saddle.project(point: p) else { continue }
            if simd_length(projection.point - p) > 1e-3 {
                offFaceVertexIndex = vertexIndex
                break
            }
        }
        guard let offFaceVertexIndex else {
            Issue.record("no usable off-face vertex found")
            return
        }
        let rawTuple = graph.vertexPoint(offFaceVertexIndex)
        let rawPoint = SIMD3(rawTuple.x, rawTuple.y, rawTuple.z)
        guard let expectedProjection = saddle.project(point: rawPoint),
            let expectedNormal = saddle.normal(atU: expectedProjection.u, v: expectedProjection.v)
        else {
            Issue.record("expected projection/normal unavailable")
            return
        }

        let faceRef = TopologyRef.literal(.init(kind: .face, index: 0))
        let vertexRef = TopologyRef.literal(.init(kind: .vertex, index: offFaceVertexIndex))
        switch graph.resolve(ConstructionAxis.normalToFace(face: faceRef, at: vertexRef)) {
        case .success(let ax):
            // The origin must be the actual on-face projected point -- the same location the
            // direction was evaluated at -- not the raw off-face vertex position.
            #expect(simd_length(ax.origin - expectedProjection.point) < 1e-6)
            #expect(
                simd_length(ax.origin - rawPoint) > 1e-3,
                "origin should differ from the raw off-face point")
            #expect(
                simd_length(simd_normalize(ax.direction) - simd_normalize(expectedNormal)) < 1e-6)
        case .failure(let e):
            Issue.record("normalToFace failed: \(e)")
        }
    }

    @Test(
        "alongEdge fails loudly, not silently, when the edge's tangent is undefined at its own start point (#894 finding 1, fifth pass)"
    )
    func alongEdgeUndefinedStartTangentFailsLoudNotSilent() {
        // A quarter-turn "top arc" on a cylindrical wall, geometrically a genuine circular
        // cross-section, constant height/radius across all 5 of `coaxialCrossSection`'s own
        // sampled fractions, built as a degree-1 BSpline whose first two poles are IDENTICAL: a
        // textbook cusp (the segment [0, 0.05] has zero length, so the right-derivative at u=0 is
        // the zero vector). `GeomLProp_CLProps::IsTangentDefined()`, and so `Edge.tangent(at:)`
        //, correctly reports undefined there, while `Edge.point(at:)` at the same parameter
        // still succeeds (plain D0 evaluation, unaffected by a degenerate derivative).
        //
        // Knots are placed at exactly the 5 fractions `coaxialCrossSection` samples (0, 0.25,
        // 0.5, 0.75, 1.0), with the extra cusp pole tucked into [0, 0.05], so every sample lands
        // exactly on a pole (an exact circle point), not on a chord between two knots, the same
        // "poles are the samples" trick `coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise`
        // above uses to avoid a chord's corner-cutting error.
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

        guard
            let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            let cuspCurve = Curve3D.bspline(
                poles: poles, knots: knots, multiplicities: mults, degree: 1),
            let topArcShape = Shape.edgeFromCurve(cuspCurve),
            let topArcEdge = Edge(topArcShape),
            let seamWire = Wire.line(from: p0bot, to: p0top),
            let seamEdge = seamWire.edges().first,
            let otherSideWire = Wire.line(from: p1top, to: p1bot),
            let otherSideEdge = otherSideWire.edges().first,
            let botArcCurve = Curve3D.arcOfCircle(
                start: p1bot,
                interior: SIMD3(radius * cos(midAngle), radius * sin(midAngle), 0.0),
                end: p0bot),
            let botArcShape = Shape.edgeFromCurve(botArcCurve),
            let botArcEdge = Edge(botArcShape),
            let wire = Wire.wireFromEdges([seamEdge, topArcEdge, otherSideEdge, botArcEdge]),
            let faceShape = Shape.face(from: surface, boundary: wire),
            let graph = BRepGraph(shape: faceShape)
        else {
            Issue.record("cusp-top-arc fixture build failed")
            return
        }

        // Confirm the fixture matches the intended scenario, the cusp edge really is
        // BSpline-typed and really does have an undefined start tangent, before asserting on
        // the fix, rather than assuming the construction above behaved as designed.
        var cuspNodeIndex: Int?
        for edgeIndex in 0..<graph.edgeCount {
            guard
                let eShape = graph.shape(nodeKind: BRepGraph.NodeKind.edge, nodeIndex: edgeIndex),
                let edge = eShape.edges().first, edge.curveType == .bsplineCurve,
                let bounds = edge.parameterBounds
            else { continue }
            #expect(edge.tangent(at: bounds.first) == nil)
            #expect(edge.point(at: bounds.first) != nil)
            cuspNodeIndex = edgeIndex
            break
        }
        guard let cuspNodeIndex else {
            Issue.record("no BSpline-curveType edge found in cusp fixture")
            return
        }

        // Pre-fix, this silently kept `Face.primaryAxis`'s unflipped sign and returned `.success`
        // with a plausible-looking but potentially-wrong-signed axis. Fixed: fails loud instead.
        let edgeRef = TopologyRef.literal(.init(kind: .edge, index: cuspNodeIndex))
        if case .failure(.degenerate) = graph.resolve(ConstructionAxis.alongEdge(edgeRef)) {
        } else {
            Issue.record("expected .degenerate when the edge's own start tangent is undefined")
        }
    }

    @Test(
        "coaxialCrossSection accepts sampled height/radius noise within the edge's own measured BRep tolerance, not just the machine-precision floor (#894 finding 2, fifth pass)"
    )
    func coaxialCrossSectionAcceptsMeasuredEdgeToleranceNoise() {
        // A degree-1 (piecewise-linear) 5-pole BSpline with a CLAMPED knot vector, [0, 0.25,
        // 0.5, 0.75, 1] with multiplicities [2, 1, 1, 1, 2], is the defining shape of a
        // degree-1 B-spline with simple interior knots: it interpolates every pole exactly at
        // its corresponding knot parameter. That gives exact, reproducible control over what
        // `coaxialCrossSection` samples at its own fractions (0, 0.25, 0.5, 0.75, 1.0), no
        // interpolation-parameterization guesswork the way `Curve3D.interpolate` would need.
        let radius = 5.0
        let height = 10.0
        // Per-point noise, ~3e-5 in magnitude, comfortably above the old flat 1e-7 floor, and
        // well inside the review's own cited 1e-4-1e-3 post-Boolean/fillet BRep tolerance range,
        // simulating a genuine circular rim that has accumulated real numerical noise.
        let angles = [0.0, Double.pi / 2, Double.pi, 3 * Double.pi / 2, 2 * Double.pi]
        let radiusNoise = [2e-5, -3e-5, 1e-5, -4e-5, 3e-5]
        let heightNoise = [3e-5, -2e-5, 4e-5, -3e-5, 1e-5]
        var poles: [SIMD3<Double>] = []
        for i in 0..<5 {
            let r = radius + radiusNoise[i]
            poles.append(SIMD3(r * cos(angles[i]), r * sin(angles[i]), height + heightNoise[i]))
        }
        guard
            let curve = Curve3D.bspline(
                poles: poles, knots: [0, 0.25, 0.5, 0.75, 1.0],
                multiplicities: [2, 1, 1, 1, 2], degree: 1),
            let edgeShape = Shape.edgeFromCurve(curve),
            let edge = Edge(edgeShape),
            let bounds = edge.parameterBounds,
            let start = edge.point(at: bounds.first),
            let end = edge.point(at: bounds.last),
            let anyShape = Shape.box(width: 1, height: 1, depth: 1),
            let graph = BRepGraph(shape: anyShape)
        else {
            Issue.record("noisy-rim fixture build failed")
            return
        }

        // The measured height/radius spread of this fixture's 5 samples (~7e-5, by construction)
        // must exceed the old flat floor for this test to prove anything, confirmed directly
        // below rather than assumed, per okf/policies/prove-the-test-fails.md.
        let axis = ShapeAxis(origin: .zero, direction: SIMD3(0, 0, 1), kind: .cylinder)
        #expect(
            !graph.coaxialCrossSection(
                of: edge, bounds: bounds, start: start, end: end, axis: axis, edgeTolerance: 0),
            "fixture noise must exceed the machine-precision floor, or this test proves nothing")

        // A realistic measured BRep_Tool::Tolerance for this rim (1e-4, well within the review's
        // own cited range) widens the comparison enough to accept the same noisy points, this is
        // the fix: pre-fix, `coaxialCrossSection` had no `edgeTolerance` parameter at all and
        // always compared against the machine-precision floor alone, so this call would have
        // returned `false` regardless of what tolerance the caller measured.
        #expect(
            graph.coaxialCrossSection(
                of: edge, bounds: bounds, start: start, end: end, axis: axis,
                edgeTolerance: 1e-4))
    }
}
