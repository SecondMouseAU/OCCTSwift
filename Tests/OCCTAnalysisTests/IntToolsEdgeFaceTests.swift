import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_EdgeFace Tests")
struct IntToolsEdgeFaceTests {
    @Test("Edge crossing face produces intersection")
    func edgeFaceIntersection() {
        // Use a box face and an edge going through it
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let edge = Shape.edgeFromPoints(SIMD3(5, 5, -1), SIMD3(5, 5, 11))
        if let b = box, let e = edge {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let parts = e.edgeFaceIntersection(with: face)
                #expect(parts != nil)
            }
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
    @Test("Exactly the two faces the edge crosses report a common part")
    func onlyCrossedFacesIntersect() {
        guard
            let box = Shape.box(width: 10, height: 10, depth: 10),
            let edge = Shape.edgeFromPoints(SIMD3(0, 0, -10), SIMD3(0, 0, 10))
        else {
            Issue.record("fixture construction failed")
            return
        }

        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)

        var hits: [(index: Int, point: SIMD3<Double>)] = []
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
                hits.append((index, point))
            }
        }

        #expect(hits.count == 2, "the edge crosses two of the six faces")

        // Both hits sit on the axis the edge runs along, at the two z faces.
        for hit in hits {
            #expect(abs(hit.point.x) < 1e-6)
            #expect(abs(hit.point.y) < 1e-6)
            #expect(abs(abs(hit.point.z) - 5.0) < 1e-6, "hit at z = \(hit.point.z)")
        }
        #expect(Set(hits.map { $0.point.z > 0 }).count == 2, "one hit per end, not two at one end")
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
    @Test("An in-plane edge is reported unclipped by the face (#2251)")
    func inPlaneEdgeIsNotClippedToTheFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(Shape.edgeFromPoints(SIMD3(5, 5, -1), SIMD3(5, 5, 11)))

        var wholeEdgeParts = 0
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
                wholeEdgeParts += 1
            }
        }
        #expect(wholeEdgeParts > 0, "no face reported the in-plane edge as an edge part")
    }
}
