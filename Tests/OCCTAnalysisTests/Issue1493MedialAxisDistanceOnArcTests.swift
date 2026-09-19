import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1493: `OCCTMedialAxisDistanceOnArc` used to compute the boundary distance only at an arc's
// two endpoint nodes and linearly interpolate between them for any intermediate `t`, instead of
// evaluating the arc's own trimmed curve at `t` and measuring `distanceToBoundary` from that real
// point (the mechanism `OCCTMedialAxisDrawArc`, two functions above it in the bridge, already
// used). Linear interpolation of distance-to-boundary is exact only when the bisector arc is a
// straight line; most arcs are circular or parabolic, where the true inscribed-circle radius is
// not linear in `t`. See `MedialAxisRectangleTests.rectangleDistanceOnArc`, which stays correct
// after this fix precisely because a rectangle's bisector arcs are all straight lines, the one
// shape family where linear interpolation happens to be exact.
//
// This suite uses an L-shaped polygon with a reflex vertex (matching
// `MedialAxisVariousShapesTests.lShapedMedialAxis`'s own fixture), which produces at least one
// genuinely curved (parabolic, vertex-to-edge) bisector arc. `MedialAxis` reports node/arc
// positions in the face's own local 2D frame (an internal rigid transform of the input polygon's
// world coordinates, e.g. a translation by the wire's own perimeter centroid), not the raw
// coordinates passed to `Wire.polygon`, so the ground truth below is not "the input point list":
// it is the local-frame boundary polygon reconstructed from `ma`'s own boundary-touching nodes,
// ordered by matching consecutive-vertex distances against the known (transform-invariant) edge
// lengths of the input shape. That reconstruction, and the curved arc's true midpoint position
// (from `OCCTMedialAxisDrawArc`, a 3-point sample gives exactly t=0, 0.5, 1 -- a sibling function
// this defect never touched), are both independent of the fixed bridge function itself.
@Suite("Issue #1493: MedialAxisDistanceOnArc evaluates the real curve, not a linear interpolation")
struct Issue1493MedialAxisDistanceOnArcTests {

    /// The L-shape from `MedialAxisVariousShapesTests.lShapedMedialAxis`: a reflex vertex at
    /// (4, 4), which produces a curved (parabolic) vertex-to-edge bisector arc. Only used here for
    /// its edge lengths (a rigid-transform invariant), never as literal coordinates to compare
    /// against `ma`'s own local frame.
    static let lShapePoints: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 4),
        SIMD2(4, 4), SIMD2(4, 8), SIMD2(0, 8),
    ]

    static var lShapeEdgeLengths: [Double] {
        let n = lShapePoints.count
        return (0..<n).map { i in simd_distance(lShapePoints[i], lShapePoints[(i + 1) % n]) }
    }

    /// Shortest distance from `p` to the closed polygon's boundary: the minimum distance to each
    /// edge segment.
    static func distanceToPolygonBoundary(_ p: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Double
    {
        var minDist = Double.greatestFiniteMagnitude
        let n = polygon.count
        for i in 0..<n {
            let a = polygon[i]
            let b = polygon[(i + 1) % n]
            let ab = b - a
            let lenSq = simd_dot(ab, ab)
            let t: Double
            if lenSq < 1e-12 {
                t = 0
            } else {
                t = max(0, min(1, simd_dot(p - a, ab) / lenSq))
            }
            let proj = a + t * ab
            minDist = min(minDist, simd_distance(p, proj))
        }
        return minDist
    }

    /// True if `a`, read cyclically starting from some rotation and possibly reversed, equals `b`
    /// within `tolerance` at every position.
    static func matchesCyclically(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
        guard a.count == b.count else { return false }
        let n = a.count
        for reversed in [false, true] {
            let seq = reversed ? Array(a.reversed()) : a
            for rotation in 0..<n {
                var ok = true
                for i in 0..<n where abs(seq[(i + rotation) % n] - b[i]) >= tolerance {
                    ok = false
                    break
                }
                if ok { return true }
            }
        }
        return false
    }

    /// Reconstructs the closed polygon boundary in whatever local frame `points` are already in,
    /// by finding the permutation whose consecutive distances match `edgeLengths` cyclically (in
    /// either direction). `points` need not be in boundary order and may include a rigid transform
    /// (rotation/reflection/translation) relative to `edgeLengths`' own source shape: only the
    /// lengths, which are transform-invariant, are used to recover the order. Returns nil if no
    /// matching permutation exists (e.g. the point count doesn't match).
    static func reconstructLocalPolygon(from points: [SIMD2<Double>], edgeLengths: [Double])
        -> [SIMD2<Double>]?
    {
        guard points.count == edgeLengths.count, points.count >= 3 else { return nil }
        let n = points.count
        var found: [Int]?

        func distances(for order: [Int]) -> [Double] {
            (0..<n).map { i in simd_distance(points[order[i]], points[order[(i + 1) % n]]) }
        }

        func permute(_ remaining: [Int], _ chosen: [Int]) {
            if found != nil { return }
            if remaining.isEmpty {
                let order = [0] + chosen
                if matchesCyclically(distances(for: order), edgeLengths, tolerance: 1e-6) {
                    found = order
                }
                return
            }
            for i in 0..<remaining.count {
                var rest = remaining
                let v = rest.remove(at: i)
                permute(rest, chosen + [v])
                if found != nil { return }
            }
        }
        permute(Array(1..<n), [])

        guard let order = found else { return nil }
        return order.map { points[$0] }
    }

    /// Distinct (deduplicated) positions of nodes lying on the shape's boundary.
    static func distinctBoundaryPositions(_ ma: MedialAxis, tolerance: Double = 1e-6)
        -> [SIMD2<Double>]
    {
        var result: [SIMD2<Double>] = []
        for node in ma.nodes where node.isOnBoundary {
            if !result.contains(where: { simd_distance($0, node.position) < tolerance }) {
                result.append(node.position)
            }
        }
        return result
    }

    @Test("A curved bisector arc's midpoint distance matches the real curve point, not the linear interpolation of its endpoints")
    func curvedArcDistanceMatchesRealCurvePoint() {
        guard let wire = Wire.polygon(Self.lShapePoints, closed: true),
            let face = Shape.face(from: wire),
            let ma = MedialAxis(of: face)
        else {
            Issue.record("Failed to compute medial axis for reflex L-shape")
            return
        }
        #expect(ma.arcCount > 0)

        // Reconstruct the boundary polygon in `ma`'s own local frame from its boundary-touching
        // nodes, matched to the input shape's edge lengths (a rigid-transform invariant).
        let boundaryPositions = Self.distinctBoundaryPositions(ma)
        #expect(
            boundaryPositions.count == Self.lShapePoints.count,
            "Expected \(Self.lShapePoints.count) distinct boundary nodes, found \(boundaryPositions.count)"
        )
        guard
            let localPolygon = Self.reconstructLocalPolygon(
                from: boundaryPositions, edgeLengths: Self.lShapeEdgeLengths)
        else {
            Issue.record("Could not reconstruct the local-frame boundary polygon from ma's own nodes")
            return
        }

        // Find the arc whose true midpoint deviates most from linear interpolation of its
        // endpoint distances -- the curved arc the fix is about. `drawArc(maxPoints: 3)` samples
        // exactly t = 0, 0.5, 1 along the arc's own trimmed curve (OCCTMedialAxisDrawArc's own
        // mechanism, unaffected by this defect), so its middle point is the arc's true geometric
        // midpoint regardless of the bridge's internal first/second-node direction bookkeeping.
        var bestArc = -1
        var bestDeviation = 0.0
        var bestMidTrue = 0.0
        var bestMidBridge = 0.0
        var bestLinear = 0.0

        for i in 1...ma.arcCount {
            let d0 = ma.distanceToBoundary(arcIndex: i, parameter: 0)
            let d1 = ma.distanceToBoundary(arcIndex: i, parameter: 1)
            guard d0 > 0.01, d1 > 0.01 else { continue }

            let points = ma.drawArc(at: i, maxPoints: 3)
            guard points.count == 3 else { continue }
            let trueMid = Self.distanceToPolygonBoundary(points[1], localPolygon)

            let linearMid = (d0 + d1) / 2.0
            let deviation = abs(linearMid - trueMid)
            if deviation > bestDeviation {
                bestDeviation = deviation
                bestArc = i
                bestMidTrue = trueMid
                bestMidBridge = ma.distanceToBoundary(arcIndex: i, parameter: 0.5)
                bestLinear = linearMid
            }
        }

        #expect(bestArc > 0, "Expected at least one curved arc in the reflex L-shape's medial axis")
        guard bestArc > 0 else { return }

        // The fixture actually exercises a curved arc: linear interpolation of the endpoint
        // distances is meaningfully wrong at the midpoint (matching the issue's own measured
        // 4%-30% errors on non-straight arcs).
        #expect(
            bestDeviation > 0.05,
            "Chosen arc \(bestArc) doesn't look curved: linear-interpolation deviation only \(bestDeviation)"
        )

        // The fix: OCCTMedialAxisDistanceOnArc(arcIndex, 0.5) must match the boundary distance
        // measured at the arc's real curve point, not the (wrong, pre-fix) linear interpolation.
        #expect(
            abs(bestMidBridge - bestMidTrue) < 1e-6,
            "Arc \(bestArc): bridge midpoint distance \(bestMidBridge) != true distance \(bestMidTrue) (linear interpolation would have given \(bestLinear))"
        )
    }

    @Test("Distance on arc still agrees with the endpoint node distances at t=0 and t=1")
    func endpointsStillMatchNodeDistances() {
        guard let wire = Wire.polygon(Self.lShapePoints, closed: true),
            let face = Shape.face(from: wire),
            let ma = MedialAxis(of: face)
        else {
            Issue.record("Failed to compute medial axis for reflex L-shape")
            return
        }
        #expect(ma.arcCount > 0)
        guard ma.arcCount > 0 else { return }

        for i in 1...ma.arcCount {
            guard let arc = ma.arc(at: i),
                let firstNode = ma.node(at: Int(arc.firstNodeIndex)),
                let secondNode = ma.node(at: Int(arc.secondNodeIndex))
            else { continue }

            let d0 = ma.distanceToBoundary(arcIndex: i, parameter: 0)
            let d1 = ma.distanceToBoundary(arcIndex: i, parameter: 1)
            #expect(abs(d0 - firstNode.distance) < 1e-6, "Arc \(i) t=0 should match its first node's distance")
            #expect(abs(d1 - secondNode.distance) < 1e-6, "Arc \(i) t=1 should match its second node's distance")
        }
    }
}
