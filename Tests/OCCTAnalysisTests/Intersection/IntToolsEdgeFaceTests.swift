import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_EdgeFace Tests")
struct IntToolsEdgeFaceTests {
    /// An edge that crosses a face produces one vertex common part, at the crossing (#766).
    ///
    /// This used to assert only `parts != nil`, which #1631's empty search window satisfied, and
    /// its fixture did not cross the face it tested: `Shape.box` is centred on the origin, so the
    /// edge from (5, 5, -1) to (5, 5, 11) runs along the box's x = 5, y = 5 corner line and never
    /// touches `faces.first`, the x = -5 face. The kernel returns no common part for that pair
    /// (Scripts/repro/766-inttoolsedgeface), so the old test could not tell a working intersector
    /// from one that finds nothing.
    ///
    /// This edge runs along +X at y = 1, z = 2 and crosses the x = -5 face once, 5 units along
    /// its length.
    @Test("Edge crossing face produces intersection")
    func edgeFaceIntersection() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(Shape.edgeFromPoints(SIMD3(-10, 1, 2), SIMD3(0, 1, 2)))
        let face = try #require(box.subShapes(ofType: .face).first)
        let parts = try #require(edge.edgeFaceIntersection(with: face))
        #expect(parts.count == 1)
        if let part = parts.first {
            #expect(part.type == .vertex)
            #expect(simd_distance(part.point, SIMD3(-5, 1, 2)) < 1e-9)
            #expect(abs(part.param1Range.first - 5) < 1e-6)
        }
    }

    /// The intersection is actually found, not merely reported as done (#1631).
    ///
    /// `IntTools_EdgeFace::myRange` defaults to `(0, 0)` and `Perform()` passes it straight to
    /// `IntTools_BeanFaceIntersector::SetBeanParameters`, so without an explicit `SetRange` the
    /// search interval is empty: every face answers `IsDone() == true` with zero common parts.
    /// The test above cannot see that, because it asserts only that the array exists.
    ///
    /// `Shape.box` is centred on the origin, so this edge runs up the middle of the box and
    /// crosses exactly two of its six faces, the ones at z = -5 and z = +5.
    ///
    /// #3012: each crossing is also a `.vertex` part with its vertex parameter and its range. The
    /// edge starts at z = -10 and is parameterised by length, so the crossings are at parameters
    /// 5 and 15, and the point's z is `-10 + parameter`. The range is the stretch of the edge
    /// within the kernel's tolerance of the face, a few times 1e-7 across for a perpendicular
    /// crossing, and it has to hold the vertex parameter. A face has no second edge, so
    /// `vertexParameter2` is absent rather than the `0.0` `IntTools_EdgeFace` leaves in that
    /// slot.
    @Test("Exactly the two faces the edge crosses report a common part")
    func onlyCrossedFacesIntersect() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(Shape.edgeFromPoints(SIMD3(0, 0, -10), SIMD3(0, 0, 10)))

        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)

        var hits: [(index: Int, part: Shape.CommonPart, point: SIMD3<Double>)] = []
        for (index, face) in faces.enumerated() {
            guard let parts = edge.edgeFaceIntersection(with: face) else {
                Issue.record("face \(index) reported failure rather than an empty result")
                return
            }
            for part in parts {
                guard let point = part.point else {
                    Issue.record("face \(index) reported a part with no point")
                    return
                }
                hits.append((index, part, point))
            }
        }

        #expect(hits.count == 2, "the edge crosses two of the six faces")

        // Both hits sit on the axis the edge runs along, at the two z faces.
        for hit in hits {
            #expect(abs(hit.point.x) < 1e-6)
            #expect(abs(hit.point.y) < 1e-6)
            #expect(abs(abs(hit.point.z) - 5.0) < 1e-6, "hit at z = \(hit.point.z)")
        }
        #expect(
            Set(hits.map { $0.point.z > 0 }).count == 2, "one hit per end, not two at one end")

        for hit in hits {
            #expect(hit.part.type == .vertex, "a transversal crossing is a vertex part")
            let vertex = try #require(
                hit.part.vertexParameter1,
                "face \(hit.index): a vertex part has a vertex parameter")
            #expect(
                abs(abs(vertex - 10) - 5) < 1e-9,
                "face \(hit.index): vertex parameter \(vertex), expected 5 or 15")
            #expect(
                abs(hit.point.z - (vertex - 10)) < 1e-9,
                "face \(hit.index): point z \(hit.point.z) is not the edge at \(vertex)")
            #expect(
                hit.part.vertexParameter2 == nil,
                "face \(hit.index): a face has no second edge, so no second vertex parameter")
            let range = hit.part.param1Range
            #expect(
                range.first < vertex && vertex < range.last,
                "face \(hit.index): range \(range) does not hold vertex parameter \(vertex)")
            let width = range.last - range.first
            #expect(
                width > 1e-7 && width < 1e-6,
                "face \(hit.index): a perpendicular crossing is within tolerance of the face over \(width)"
            )
        }
    }

    /// #3012: the range is the stretch of the edge within tolerance of the face, so it widens as
    /// the edge runs closer to the face's plane, and the vertex parameter does not move.
    ///
    /// A 200 x 200 x 10 slab is centred on the origin, so its top face is the plane z = 5 and is
    /// 200 across, far more than the edge needs. Each edge runs 20 long in x and crosses z = 5 at
    /// the origin, rising by 0.02 over its length (a slope of 1e-3) and by 0.0002 (1e-5). Each is
    /// parameterised by length from its start, so it crosses at about 10 (10.000005 for the
    /// first, whose length is a little over 20).
    ///
    /// The width is the tolerance band over the slope, so a hundredth of the slope is a hundred
    /// times the range. Measured on the pinned kernel it is 6.1e-4 and 6.0e-2, a ratio of 98.4
    /// (the bean intersector's own convergence tolerance is why it is not exactly 100), against
    /// 3e-7 for a perpendicular crossing. The bridge's `(t, t)` was zero across at every slope,
    /// which says an edge grazing a face by one part in a hundred thousand crosses it at a single
    /// point and is the information this test pins.
    @Test("A shallower crossing widens the range, not the vertex parameter (#3012)")
    func shallowCrossingsWidenTheRange() throws {
        let slab = try #require(Shape.box(width: 200, height: 200, depth: 10))
        var widths: [Double] = []
        for rise in [0.02, 0.0002] {
            let edge = try #require(
                Shape.edgeFromPoints(SIMD3(-10, 0, 5 - rise / 2), SIMD3(10, 0, 5 + rise / 2)))
            let length = (20.0 * 20.0 + rise * rise).squareRoot()

            var parts: [Shape.CommonPart] = []
            for face in slab.subShapes(ofType: .face) {
                let found = try #require(edge.edgeFaceIntersection(with: face))
                parts += found
            }
            #expect(
                parts.count == 1, "rise \(rise): \(parts.count) parts, expected the one at z = 5")
            let part = try #require(parts.first)
            #expect(part.type == .vertex)
            let vertex = try #require(part.vertexParameter1)
            #expect(
                abs(vertex - length / 2) < 1e-6,
                "rise \(rise): vertex parameter \(vertex), expected the middle, \(length / 2)")
            #expect(part.vertexParameter2 == nil)
            let range = part.param1Range
            #expect(
                range.first < vertex && vertex < range.last,
                "rise \(rise): range \(range) does not hold vertex parameter \(vertex)")
            widths.append(range.last - range.first)
        }
        #expect(widths.count == 2)
        // (tolE + tolF) / slope is 3e-4 either side at a slope of 1e-3, so the first range is
        // about 6e-4 across, and the bean intersector's own tolerance puts it at 6.1e-4.
        #expect(widths[0] > 3e-4 && widths[0] < 1.2e-3, "slope 1e-3: width \(widths[0])")
        let ratio = widths[1] / widths[0]
        #expect(ratio > 95 && ratio < 105, "a hundredth of the slope is ~100x the range: \(ratio)")
    }

    /// #3012: OCCT resolves the vertex parameter before it uses it, and this is the one fixture
    /// where that changes the answer.
    ///
    /// `IntTools_Tools::VertexParameter` returns `IntTools_CommonPrt::VertexParameter1` only if it
    /// lies inside `Range1()` and the middle of `Range1()` otherwise (`IntTools_Tools.cxx:615-623`),
    /// and `BOPAlgo_PaveFiller::PerformEF` builds its vertex from that
    /// (`BOPAlgo_PaveFiller_5.cxx:412`). So a vertex parameter always lies inside its own range, by
    /// construction, and an API that read the raw field instead would break the invariant wherever
    /// the raw value escapes.
    ///
    /// A circle of radius 5 in the XZ plane touches a centred 10 x 10 x 10 box at four points, at
    /// the circle's parameters 0, pi/2, pi and 3pi/2, tangent to the x = +-5 and z = +-5 faces. The
    /// contact at parameter 0 is the circle's own seam: the kernel reports it as two half-windows,
    /// one at each end of the edge's range, so the face holds two parts and the box five in all.
    /// The one at the far end has a raw `VertexParameter1` of 2pi, which sits one ulp past
    /// `Range1().Last()` (8.9e-16, measured in `Scripts/repro/3012-commonpart-range1/`), so OCCT
    /// takes the middle of the window instead, 1.7e-4 short of the seam. That point is still on the
    /// circle and still within the kernel's tolerance of the face plane, which is what the last
    /// assertions require, and it is the point OCCT would build its vertex at.
    @Test("A vertex parameter stays inside its own range at a closed edge's seam (#3012)")
    func vertexParameterStaysInsideItsRangeAtTheSeam() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 1, 0), radius: 5))
        let ring = try #require(Shape.edgeFromCurve(circle, u1: 0, u2: 2 * .pi))

        var parts: [Shape.CommonPart] = []
        for face in box.subShapes(ofType: .face) {
            let found = try #require(ring.edgeFaceIntersection(with: face))
            parts += found
        }
        #expect(parts.count == 5, "four tangent contacts, one of them split at the seam")

        var seamParts = 0
        for part in parts {
            #expect(part.type == .vertex, "a tangent contact is a vertex part")
            let vertex = try #require(part.vertexParameter1)
            let range = part.param1Range
            #expect(
                range.first <= vertex && vertex <= range.last,
                "vertex parameter \(vertex) escapes its range \(range)")
            if range.first < 1e-9 || abs(range.last - 2 * .pi) < 1e-9 { seamParts += 1 }

            let point = try #require(part.point)
            #expect(abs(simd_length(point) - 5) < 1e-9, "point \(point) is off the circle")
            #expect(abs(point.y) < 1e-9, "point \(point) is off the XZ plane")
            let reach = max(abs(point.x), abs(point.z))
            #expect(abs(reach - 5) < 1e-6, "point \(point) is not at one of the four contacts")
        }
        #expect(seamParts == 2, "the seam contact is reported once at each end of the range")
    }

    /// #2251: an edge-type part's point sits on the edge, not on the chord across the overlap.
    ///
    /// `IntTools_EdgeFace` does set bounding points (`IntTools_EdgeFace.cxx:605`), from the curve at
    /// the two ends of the part's range, and the bridge used to report their 3D midpoint. For a
    /// semicircle that midpoint is the circle's own centre: an arc of radius 10 spanning [0, pi] runs
    /// from (10, 0, 0) to (-10, 0, 0), so the reported "representative point of the intersection"
    /// was (0, 0, 0), a point 10 away from every point of the intersection.
    ///
    /// The plate is shifted so that one of its faces lies in the z = 0 plane the arc lies in, and it
    /// is 40 wide so the whole arc is inside the face.
    ///
    /// #3012: an `.edge` part carries no vertex parameter, here as in the edge-edge case.
    @Test("An arc lying in a face reports a point on the arc, not the chord midpoint (#2251)")
    func arcInFaceReportsAPointOnTheArc() throws {
        let plate = try #require(
            Shape.box(width: 40, height: 40, depth: 2)?.translated(by: SIMD3(0, 0, 1)))
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10))
        let arc = try #require(Shape.edgeFromCurve(circle, u1: 0, u2: .pi))

        var found = 0
        for face in plate.subShapes(ofType: .face) {
            guard let parts = arc.edgeFaceIntersection(with: face) else {
                Issue.record("a plate face reported failure rather than an empty result")
                return
            }
            for part in parts {
                found += 1
                #expect(part.type == .edge, "the whole arc lies in the face")
                #expect(part.vertexParameter1 == nil, "an edge part has no vertex parameter")
                #expect(part.vertexParameter2 == nil, "an edge part has no vertex parameter")
                guard let point = part.point else {
                    Issue.record("an edge part over the whole arc reported no point")
                    continue
                }
                #expect(
                    abs(simd_length(point) - 10.0) < 1e-6,
                    "point \(point) is \(simd_length(point)) from the centre, not on the arc")
                #expect(abs(point.z) < 1e-9)
            }
        }
        #expect(found == 1, "expected one face to hold the arc, \(found) reported a part")
    }

    /// #2251's second half: an in-plane edge part is not clipped to the face, and that is OCCT.
    ///
    /// The edge from (5, 5, -1) to (5, 5, 11) lies in the x = 5 plane of a box spanning z in [-5, 5]
    /// and runs past the face at both ends. `IntTools_EdgeFace` reports one edge-type part covering
    /// the edge's whole parameter range, (0, 12), rather than the (1, 11) the face would clip it to.
    /// Recorded here so a caller does not read an edge part as bounded by the face.
    ///
    /// #3012: the same edge also crosses the z = 5 face end-on, at parameter 6, and that part is a
    /// `.vertex` with its vertex parameter, while the in-plane `.edge` parts have none.
    @Test("An in-plane edge is reported unclipped by the face (#2251)")
    func inPlaneEdgeIsNotClippedToTheFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(Shape.edgeFromPoints(SIMD3(5, 5, -1), SIMD3(5, 5, 11)))

        var wholeEdgeParts = 0
        var vertexParts = 0
        for face in box.subShapes(ofType: .face) {
            guard let parts = edge.edgeFaceIntersection(with: face) else {
                Issue.record("a box face reported failure rather than an empty result")
                return
            }
            for part in parts where part.type == .edge {
                #expect(part.param1Range.first == 0.0)
                #expect(
                    abs(part.param1Range.last - 12.0) < 1e-9,
                    "range ended at \(part.param1Range.last), so the part was clipped after all")
                #expect(part.vertexParameter1 == nil, "an edge part has no vertex parameter")
                #expect(part.vertexParameter2 == nil, "an edge part has no vertex parameter")
                wholeEdgeParts += 1
            }
            for part in parts where part.type == .vertex {
                let vertex = try #require(part.vertexParameter1)
                #expect(abs(vertex - 6) < 1e-9, "the z = 5 face is crossed at parameter 6")
                #expect(part.vertexParameter2 == nil)
                vertexParts += 1
            }
        }
        // The edge runs along the box's x = 5, y = 5 corner line, so it lies in both of the two
        // faces that meet there, and it crosses z = 5 end-on once.
        #expect(wholeEdgeParts == 2, "\(wholeEdgeParts) faces reported the in-plane edge")
        #expect(vertexParts == 1, "\(vertexParts) faces reported the end-on crossing")
    }
}
