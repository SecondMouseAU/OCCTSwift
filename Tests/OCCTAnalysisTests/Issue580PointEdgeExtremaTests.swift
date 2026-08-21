import Testing
import Foundation
import simd
@testable import OCCTSwift

// MARK: - #580: the nearest point on an edge of a shape

/// `Shape.pointEdgeExtrema(point:edgeIndex:)` is the third entry point promising the closest point
/// on an edge, after the two #539 fixed. It carried the same defect and one of its own:
///
/// - It reported the minimum over `BRepExtrema_ExtPC`'s extrema, which is not the minimum over the
///   edge. Extrema are perpendicular feet, so they exclude the edge's own two ends, and the only
///   one in range can be a *maximum*: a point below a half circle of radius 5 read as 11 away when
///   it is 7.81 away. When no foot exists at all, an ordinary point past the end of a segment,
///   `IsDone()` is false and the whole call answered `nil`. Over 189 edge/point combinations it was
///   right 101 times, wrong 34 and silent 54.
///
/// - Its `edgeIndex` walked a bare `TopExp_Explorer`, which counts one entry per *occurrence*. A
///   box's 12 edges are 24 occurrences, so from index 9 onwards it measured to a different edge
///   than `Shape.edges()` and `Shape.edge(at:)` name (#541's contract).
///
/// Both now route through what everything else uses: `occtNearestPointOnCurveRange` for the
/// geometry and `occtEdgeAt` for the index. `solutionCount` keeps its own meaning, how many
/// perpendicular feet the point has, and stops doubling as a success flag.
@Suite("The nearest point on an edge of a shape (#580)")
struct Issue580PointEdgeExtremaTests {

    /// A segment from (3, 0, 0) to (8, 0, 0), as one edge.
    private static func segment() throws -> Shape {
        let wire = try #require(Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(8, 0, 0)))
        return try #require(Shape.fromWire(wire))
    }

    /// The upper half of a circle of radius 5 in the XY plane, as one edge.
    private static func halfArc() throws -> Shape {
        let wire = try #require(Wire.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi))
        return try #require(Shape.fromWire(wire))
    }

    // MARK: The four rows the issue was filed on

    /// A point below the arc has no perpendicular foot on it, so the nearest point is an end at
    /// (±5, 0, 0), sqrt(25 + 36) = 7.81025 away. The sole extremum `BRepExtrema_ExtPC` finds is the
    /// top of the arc, a maximum, and it was reported as the answer.
    @Test("A point below a half arc gets the nearer end, not the far side")
    func belowTheArcGetsTheEnd() throws {
        let arc = try Self.halfArc()
        let result = try #require(arc.pointEdgeExtrema(point: SIMD3(0, -6, 0), edgeIndex: 0))

        #expect(abs(result.distance - (25.0 + 36.0).squareRoot()) < 1e-6)   // 7.81025, was 11
        #expect(abs(result.pointOnEdge.y) < 1e-6)
        #expect(abs(abs(result.pointOnEdge.x) - 5) < 1e-6)

        // There is exactly one extremum, and it is the maximum at the top of the arc, the answer
        // this used to give. So a non-zero solutionCount does not mean the nearest point is one of
        // the extrema, only that the point has that many perpendicular feet on the edge.
        #expect(result.solutionCount == 1)
        #expect(simd_distance(result.pointOnEdge, SIMD3(0, 5, 0)) > 1)
    }

    /// (3, -4, 0) is exactly on the radius-5 circle and exactly not on the upper half of it. The
    /// nearest point on the arc is its start at (5, 0, 0), sqrt(4 + 16) = 4.47214 away.
    @Test("A point on the circle but off the arc measures to the arc")
    func onTheCircleButOffTheArc() throws {
        let arc = try Self.halfArc()
        let result = try #require(arc.pointEdgeExtrema(point: SIMD3(3, -4, 0), edgeIndex: 0))

        #expect(abs(result.distance - (4.0 + 16.0).squareRoot()) < 1e-6)    // 4.47214, was 10
        #expect(simd_distance(result.pointOnEdge, SIMD3(5, 0, 0)) < 1e-6)
    }

    /// Past the end of a straight edge there is no foot at all, so `IsDone()` was false and the
    /// method answered `nil`, for a point 92 units from the edge.
    @Test("A point past the end of a segment is answered, not refused")
    func pastTheEndIsAnswered() throws {
        let segment = try Self.segment()

        let beyond = try #require(segment.pointEdgeExtrema(point: SIMD3(100, 0, 0), edgeIndex: 0))
        #expect(abs(beyond.distance - 92) < 1e-9)                           // was nil
        #expect(simd_distance(beyond.pointOnEdge, SIMD3(8, 0, 0)) < 1e-9)
        #expect(beyond.solutionCount == 0)

        let before = try #require(segment.pointEdgeExtrema(point: .zero, edgeIndex: 0))
        #expect(abs(before.distance - 3) < 1e-9)                            // was nil
        #expect(simd_distance(before.pointOnEdge, SIMD3(3, 0, 0)) < 1e-9)
    }

    // MARK: solutionCount is a count, and nil is a missing edge

    /// A point that does have a perpendicular foot reports one, and the geometry is the foot. This
    /// is the case the pre-#580 implementation already answered correctly, so it pins that the
    /// field still means what it meant and still comes from `BRepExtrema_ExtPC`.
    @Test("A point with a perpendicular foot reports it, and lands on it")
    func perpendicularFootIsReported() throws {
        let segment = try Self.segment()
        let onSegment = try #require(segment.pointEdgeExtrema(point: SIMD3(5, 2, 0), edgeIndex: 0))
        #expect(abs(onSegment.distance - 2) < 1e-9)
        #expect(simd_distance(onSegment.pointOnEdge, SIMD3(5, 0, 0)) < 1e-9)
        #expect(onSegment.solutionCount >= 1)

        let arc = try Self.halfArc()
        let above = try #require(arc.pointEdgeExtrema(point: SIMD3(0, 6, 0), edgeIndex: 0))
        #expect(abs(above.distance - 1) < 1e-6)
        #expect(simd_distance(above.pointOnEdge, SIMD3(0, 5, 0)) < 1e-6)
        #expect(above.solutionCount >= 1)
    }

    /// `nil` now means only what the documentation says: no such edge index, or an edge with no 3D
    /// curve. Under the old guard it also meant "this point has no perpendicular foot", which is
    /// the case the three tests above cover.
    @Test("nil is reserved for an index that names no edge")
    func nilMeansNoSuchEdge() throws {
        let segment = try Self.segment()
        #expect(segment.pointEdgeExtrema(point: .zero, edgeIndex: 1) == nil)
        #expect(segment.pointEdgeExtrema(point: .zero, edgeIndex: -1) == nil)
        #expect(segment.pointEdgeExtrema(point: .zero, edgeIndex: 99) == nil)
    }

    // MARK: The index contract, and agreement with the other entry point

    /// The index is a position in the enumeration `Shape.edges()` reads. The bare explorer this
    /// used to walk counts a box's 12 edges as 24 occurrences, so from index 9 the two named
    /// different edges, measured on the pinned kernel, edge 9 was (10, 0, 5) here against
    /// (5, 0, 10) everywhere else.
    @Test("edgeIndex names the edge Shape.edges() names")
    func edgeIndexMatchesEdgesEnumeration() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        #expect(edges.count == 12)

        // A probe inside the box, so every edge has a perpendicular foot and this measures the
        // index contract on its own rather than tripping the old nil guard first. Asymmetric, so
        // that naming the wrong edge cannot coincidentally agree.
        let probe = SIMD3<Double>(1, 2, 3)
        for (index, edge) in edges.enumerated() {
            let viaShape = try #require(box.pointEdgeExtrema(point: probe, edgeIndex: index),
                                        "edge \(index)")
            let viaEdge = try #require(edge.project(point: probe), "edge \(index)")
            #expect(abs(viaShape.distance - viaEdge.distance) < 1e-9, "edge \(index)")
            #expect(simd_distance(viaShape.pointOnEdge, viaEdge.point) < 1e-9, "edge \(index)")
        }
    }

    /// The whole point of routing through `occtNearestPointOnCurveRange`: two entry points asking
    /// the same question about the same edge and the same point cannot answer differently. Before
    /// #580 they disagreed on every arc case above.
    @Test("Shape.pointEdgeExtrema and Edge.project agree")
    func agreesWithEdgeProject() throws {
        let arc = try Self.halfArc()
        let edge = try #require(arc.edges().first)

        for point in [SIMD3<Double>(0, -6, 0), SIMD3(3, -4, 0), SIMD3(0, 6, 0),
                      SIMD3(0, -1, 0), SIMD3(6, 0, 0), .zero] {
            let viaShape = try #require(arc.pointEdgeExtrema(point: point, edgeIndex: 0), "\(point)")
            let viaEdge = try #require(edge.project(point: point), "\(point)")
            #expect(abs(viaShape.distance - viaEdge.distance) < 1e-6, "\(point)")
            #expect(simd_distance(viaShape.pointOnEdge, viaEdge.point) < 1e-6, "\(point)")
            #expect(abs(viaShape.parameter - viaEdge.parameter) < 1e-6, "\(point)")
        }
    }

    /// The caller this broke: a proximity test on a shape's edges. Every edge of a box is within
    /// 200 of a far probe, and the nearest of them is the one the truth says it is.
    @Test("A proximity scan over a shape's edges reads the real distances")
    func proximityScanOverEdges() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let probe = SIMD3<Double>(20, 0, 0)

        var nearest = Double.greatestFiniteMagnitude
        var answered = 0
        for index in 0..<box.edges().count {
            guard let hit = box.pointEdgeExtrema(point: probe, edgeIndex: index) else { continue }
            answered += 1
            nearest = min(nearest, hit.distance)
        }

        // Every edge answers; under the old guard most of them returned nil for this probe.
        #expect(answered == 12)
        // Shape.box is centred on the origin, so its +X face spans x = 5 and the nearest edge point
        // to (20, 0, 0) is the midpoint of a vertical edge at (5, ±5, 0): sqrt(225 + 25) = 15.8114.
        #expect(abs(nearest - (225.0 + 25.0).squareRoot()) < 1e-6)
    }
}
