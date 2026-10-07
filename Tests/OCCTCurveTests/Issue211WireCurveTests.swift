import Foundation
import Testing
import simd

@testable import OCCTSwift

/// One point against its expected value, with a message that names the site.
private func expectPoint(
    _ got: SIMD3<Double>?, _ want: SIMD3<Double>, _ what: String, tolerance: Double = 1e-9,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let got else {
        Issue.record("\(what): nil, want \(want)", sourceLocation: sourceLocation)
        return
    }
    #expect(
        simd_distance(got, want) < tolerance, "\(what): got \(got), want \(want)",
        sourceLocation: sourceLocation)
}

/// The point of the L-shaped wire `(0,0,0) -> (10,0,0) -> (10,10,0)` at arc length `s`.
///
/// Closed form: the first edge runs along +X for 10, the second along +Y for 10.
private func lPoint(_ s: Double) -> SIMD3<Double> {
    s <= 10 ? SIMD3(s, 0, 0) : SIMD3(10, s - 10, 0)
}

// #211: WireCurve, treat a multi-edge wire as one arc-length-parameterized curve.
@Suite("Issue #211, WireCurve arc-length adaptor")
struct Issue211WireCurve {

    // An L-shaped open wire: (0,0,0)→(10,0,0)→(10,10,0). Two edges, total length 20.
    private func lWire() throws -> Wire {
        try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0)], closed: false))
    }

    private func lCurve() throws -> WireCurve {
        try #require(WireCurve(try lWire()))
    }

    @Test("length spans all edges")
    func length() throws {
        let wc = try lCurve()
        // Two straight edges of 10: the sum, not the first edge, and not the straight-line
        // distance between the ends (14.14).
        #expect(abs(wc.length - 20.0) < 1e-9)
    }

    @Test("point(atAbscissa:) walks across the edge boundary")
    func pointAtAbscissa() throws {
        let wc = try lCurve()
        expectPoint(wc.point(atAbscissa: 0), SIMD3(0, 0, 0), "start")
        expectPoint(wc.point(atAbscissa: 5), SIMD3(5, 0, 0), "mid first edge")
        expectPoint(wc.point(atAbscissa: 10), SIMD3(10, 0, 0), "the corner")
        expectPoint(wc.point(atAbscissa: 15), SIMD3(10, 5, 0), "mid second edge")
        expectPoint(wc.point(atAbscissa: 20), SIMD3(10, 10, 0), "end")
        // Off the round numbers, either side of the corner, so a walk that is only right at
        // the edge boundaries and its midpoints does not pass.
        for s in [1.0, 2.5, 7.25, 9.75, 10.5, 12.5, 17.75, 19.5] {
            expectPoint(wc.point(atAbscissa: s), lPoint(s), "abscissa \(s)")
        }
    }

    @Test("tangent flips direction across the corner")
    func tangentAcrossCorner() throws {
        let wc = try lCurve()
        // Unit length and the exact edge direction, on both edges and at several abscissae of
        // each: a doubled, negated or axis-swapped tangent each fail one of these.
        for s in [0.0, 2.5, 5, 9.5] {
            let t = try #require(wc.tangent(atAbscissa: s), "tangent at \(s)")
            expectPoint(t, SIMD3(1, 0, 0), "first edge at \(s)")
        }
        for s in [10.5, 15, 17.5, 20] {
            let t = try #require(wc.tangent(atAbscissa: s), "tangent at \(s)")
            expectPoint(t, SIMD3(0, 1, 0), "second edge at \(s)")
        }
    }

    @Test("even arc-length sampling yields the requested count")
    func evenSampling() throws {
        let wc = try lCurve()
        let n = 20
        let pts = (0...n).compactMap { wc.point(atAbscissa: wc.length * Double($0) / Double(n)) }
        #expect(pts.count == n + 1)
        // And every sample is where the closed form puts it, not merely present.
        for (i, p) in pts.enumerated() {
            expectPoint(p, lPoint(Double(i)), "sample \(i)")
        }
    }

    @Test("points(count:) returns equally-spaced points incl. endpoints")
    func uniformPoints() throws {
        let wc = try lCurve()
        // abscissae 0,5,10,15,20 on a length-20 wire
        let pts = wc.points(count: 5)
        #expect(pts.count == 5)
        if pts.count == 5 {
            expectPoint(pts[0], SIMD3(0, 0, 0), "first")
            expectPoint(pts[1], SIMD3(5, 0, 0), "second")
            expectPoint(pts[2], SIMD3(10, 0, 0), "the corner")
            expectPoint(pts[3], SIMD3(10, 5, 0), "fourth")
            expectPoint(pts[4], SIMD3(10, 10, 0), "last")
        }
        // Other counts, each point against the closed form at abscissa 20 i / (n - 1): two is
        // the endpoints alone, and 21 is a unit step that crosses the corner on a sample.
        for n in [2, 3, 4, 21] {
            let sampled = wc.points(count: n)
            #expect(sampled.count == n, "count \(n)")
            if sampled.count == n {
                for (i, p) in sampled.enumerated() {
                    expectPoint(p, lPoint(20.0 * Double(i) / Double(n - 1)), "n=\(n) sample \(i)")
                }
            }
        }
        #expect(wc.points(count: 1).isEmpty)  // need >= 2
        #expect(wc.points(count: 0).isEmpty)
        #expect(wc.points(count: -3).isEmpty)
    }

    // #422: parameterRange/point(atParameter:)/tangent(atParameter:) were previously only
    // exercised indirectly, as internals of point/tangent(atAbscissa:).
    @Test("parameterRange bounds match the wire's start/end via point(atParameter:)")
    func parameterRangeMatchesEndpoints() throws {
        let wc = try lCurve()
        let range = wc.parameterRange
        // Measured: one unit of native parameter per edge, so [0, 2] for two edges. The range is
        // not the arc length (20): a range that were would be the length of the wire read as a
        // parameter.
        #expect(abs(range.first) < 1e-12)
        #expect(abs(range.last - 2.0) < 1e-12)
        expectPoint(wc.point(atParameter: range.first), SIMD3(0, 0, 0), "point at first")
        expectPoint(wc.point(atParameter: range.last), SIMD3(10, 10, 0), "point at last")
        // The native parameter at the corner is 1, and a quarter of the way along is 0.5 of the
        // first edge: the parameter is not the abscissa.
        expectPoint(wc.point(atParameter: 1), SIMD3(10, 0, 0), "the corner by parameter")
        expectPoint(wc.point(atParameter: 0.25), SIMD3(2.5, 0, 0), "a quarter of edge one")
        expectPoint(wc.point(atParameter: 1.5), SIMD3(10, 5, 0), "half of edge two")
        // parameter(atAbscissa:) is the inverse map: both ends and the corner land on the range.
        let atStart = try #require(wc.parameter(atAbscissa: 0))
        let atCorner = try #require(wc.parameter(atAbscissa: 10))
        let atQuarter = try #require(wc.parameter(atAbscissa: 12.5))
        let atEnd = try #require(wc.parameter(atAbscissa: wc.length))
        #expect(abs(atStart - range.first) < 1e-9)
        #expect(abs(atCorner - 1.0) < 1e-9)
        #expect(abs(atQuarter - 1.25) < 1e-9)
        #expect(abs(atEnd - range.last) < 1e-9)
        // Unit tangent, in the direction of the first edge at the start and of the second at
        // the end.
        expectPoint(wc.tangent(atParameter: range.first), SIMD3(1, 0, 0), "tangent at first")
        expectPoint(wc.tangent(atParameter: range.last), SIMD3(0, 1, 0), "tangent at last")
    }

    // #422: points(spacing:) was untested on both EdgeCurve and WireCurve.
    @Test("points(spacing:) divides the wire evenly and includes both endpoints")
    func pointsSpacing() throws {
        let wc = try lCurve()
        let pts = wc.points(spacing: 4)  // length 20 -> 6 points, 4 apart
        #expect(pts.count == 6)
        if pts.count == 6 {
            for (i, p) in pts.enumerated() {
                expectPoint(p, lPoint(4.0 * Double(i)), "spacing 4, point \(i)")
            }
        }
        // 20 / 6 = 3.33 intervals rounds to 3, so 4 points at a stretched step of 20/3; 20 / 7 =
        // 2.86 rounds to 3 as well (a floor would give 2), and 20 / 1000 rounds to 0 intervals,
        // which still returns the two endpoints.
        for (spacing, count) in [(6.0, 4), (7.0, 4), (1000.0, 2)] {
            let sampled = wc.points(spacing: spacing)
            #expect(sampled.count == count, "spacing \(spacing)")
            if sampled.count == count {
                for (i, p) in sampled.enumerated() {
                    expectPoint(
                        p, lPoint(20.0 * Double(i) / Double(count - 1)),
                        "spacing \(spacing), point \(i)")
                }
            }
        }
        #expect(wc.points(spacing: 0).isEmpty)  // spacing must be > 0
        #expect(wc.points(spacing: -1).isEmpty)
    }
}

// #211/#212: EdgeCurve, single-edge arc-length adaptor.
@Suite("Issue #211/#212, EdgeCurve arc-length adaptor")
struct Issue211EdgeCurve {
    /// A straight edge of length 10 along +X.
    ///
    /// Built from a two-point wire rather than taken from a box: which of a box's twelve edges
    /// comes first, and which way it runs, is not something to rely on.
    private func straightEdge() throws -> Edge {
        let wire = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0)], closed: false))
        return try #require(wire.edges().first)
    }

    /// A quarter circle of radius 5 about the origin, from (5,0,0) to (0,5,0): length 5 pi / 2,
    /// native parameter the angle, so abscissa and parameter differ by the factor 5.
    private func quarterCircle() throws -> Edge {
        let shape = try #require(
            Shape.edgeFromCircle(
                center: .zero, axis: SIMD3(0, 0, 1), radius: 5, p1: 0, p2: .pi / 2))
        return try #require(shape.edges(where: { _ in true }).first)
    }

    private func anEdge() -> Edge? {
        Shape.box(width: 10, height: 10, depth: 10)?.edges(where: { _ in true }).first
    }

    @Test("length and endpoint sampling on a box edge")
    func lengthAndSampling() throws {
        let boxEdge = try #require(anEdge())
        let ec = try #require(EdgeCurve(boxEdge))
        #expect(abs(ec.length - 10.0) < 1e-9)  // box side
        let pts = ec.points(count: 3)
        #expect(pts.count == 3)
        // The midpoint of the edge, measured on the edge's own endpoints, and the two ends.
        let ends = boxEdge.endpoints
        if pts.count == 3 {
            expectPoint(pts[0], ends.start, "first sample is the start")
            expectPoint(pts[1], (ends.start + ends.end) / 2, "middle sample is the midpoint")
            expectPoint(pts[2], ends.end, "last sample is the end")
        }
        // mid-abscissa point lies on the edge, at its midpoint
        expectPoint(
            ec.point(atAbscissa: ec.length / 2), (ends.start + ends.end) / 2, "mid abscissa")
        // unit tangent, along the edge
        let t = try #require(ec.tangent(atAbscissa: ec.length / 2), "tangent nil")
        #expect(abs(simd_length(t) - 1.0) < 1e-9)
        expectPoint(t, simd_normalize(ends.end - ends.start), "tangent along the edge")

        // The same on the straight edge whose direction is known: along +X, length 10.
        let line = try #require(EdgeCurve(try straightEdge()))
        #expect(abs(line.length - 10.0) < 1e-9)
        expectPoint(line.point(atAbscissa: 2.5), SIMD3(2.5, 0, 0), "abscissa 2.5")
        expectPoint(line.tangent(atAbscissa: 2.5), SIMD3(1, 0, 0), "tangent along +X")
        let line3 = line.points(count: 3)
        #expect(line3.count == 3)
        if line3.count == 3 {
            expectPoint(line3[0], SIMD3(0, 0, 0), "first")
            expectPoint(line3[1], SIMD3(5, 0, 0), "second")
            expectPoint(line3[2], SIMD3(10, 0, 0), "third")
        }

        // On a curved edge the abscissa is not the native parameter: half the length of the
        // quarter circle is the 45-degree point, and the tangent there is (-1, 1, 0) / sqrt 2.
        let arc = try #require(EdgeCurve(try quarterCircle()))
        #expect(abs(arc.length - 5 * .pi / 2) < 1e-9)
        let mid = 5.0 / 2.0.squareRoot()
        expectPoint(arc.point(atAbscissa: arc.length / 2), SIMD3(mid, mid, 0), "45 degrees")
        expectPoint(
            arc.tangent(atAbscissa: arc.length / 2), SIMD3(-1, 1, 0) / 2.0.squareRoot(),
            "tangent at 45 degrees")
        let samples = arc.points(count: 5)
        #expect(samples.count == 5)
        if samples.count == 5 {
            for (i, p) in samples.enumerated() {
                let angle = Double(i) * .pi / 8
                expectPoint(
                    p, SIMD3(5 * Foundation.cos(angle), 5 * Foundation.sin(angle), 0),
                    "arc sample \(i)")
            }
        }
    }

    // #422: parity with WireCurve's count < 2 empty-array case (previously untested on EdgeCurve).
    @Test("points(count:) below 2 returns an empty array")
    func pointsCountBelowTwoIsEmpty() throws {
        let ec = try #require(EdgeCurve(try straightEdge()))
        #expect(ec.points(count: 1).isEmpty)
        #expect(ec.points(count: 0).isEmpty)
        #expect(ec.points(count: -1).isEmpty)
        // The control: two is the smallest count that is served, and it is the two endpoints.
        let two = ec.points(count: 2)
        #expect(two.count == 2)
        if two.count == 2 {
            expectPoint(two[0], SIMD3(0, 0, 0), "start")
            expectPoint(two[1], SIMD3(10, 0, 0), "end")
        }
    }

    // #422: parameterRange/point(atParameter:)/tangent(atParameter:) were previously only
    // exercised indirectly, as internals of point/tangent(atAbscissa:).
    @Test("parameterRange bounds match the edge's start/end via point(atParameter:)")
    func parameterRangeMatchesEndpoints() throws {
        let ec = try #require(EdgeCurve(try straightEdge()))
        let range = ec.parameterRange
        // A line edge's native parameter is its length: [0, 10].
        #expect(abs(range.first) < 1e-12)
        #expect(abs(range.last - 10) < 1e-12)
        expectPoint(ec.point(atParameter: range.first), SIMD3(0, 0, 0), "start by parameter")
        expectPoint(ec.point(atParameter: range.last), SIMD3(10, 0, 0), "end by parameter")
        expectPoint(ec.point(atAbscissa: 0), SIMD3(0, 0, 0), "start by abscissa")
        expectPoint(ec.point(atAbscissa: ec.length), SIMD3(10, 0, 0), "end by abscissa")
        expectPoint(ec.tangent(atParameter: range.first), SIMD3(1, 0, 0), "tangent at first")

        // On the quarter circle the range is the angle, [0, pi/2], and abscissa 5 (one radian)
        // is parameter 1: the map is the identity only for a line.
        let arc = try #require(EdgeCurve(try quarterCircle()))
        let arcRange = arc.parameterRange
        #expect(abs(arcRange.first) < 1e-12)
        #expect(abs(arcRange.last - .pi / 2) < 1e-12)
        let atFive = try #require(arc.parameter(atAbscissa: 5))
        #expect(abs(atFive - 1.0) < 1e-9)
        let atEnd = try #require(arc.parameter(atAbscissa: arc.length))
        #expect(abs(atEnd - arcRange.last) < 1e-9)
        expectPoint(
            arc.point(atParameter: 1), SIMD3(5 * Foundation.cos(1.0), 5 * Foundation.sin(1.0), 0),
            "angle 1")
        expectPoint(
            arc.tangent(atParameter: arcRange.first), SIMD3(0, 1, 0), "tangent at the start")
        expectPoint(
            arc.tangent(atParameter: arcRange.last), SIMD3(-1, 0, 0), "tangent at the end")
    }

    // #422: points(spacing:) was untested on both EdgeCurve and WireCurve.
    @Test("points(spacing:) divides the edge evenly and includes both endpoints")
    func pointsSpacing() throws {
        let ec = try #require(EdgeCurve(try straightEdge()))
        let pts = ec.points(spacing: 5)  // length 10 -> 3 points, 5 apart
        #expect(pts.count == 3)
        if pts.count == 3 {
            expectPoint(pts[0], SIMD3(0, 0, 0), "first")
            expectPoint(pts[1], SIMD3(5, 0, 0), "second, 5 from the first")
            expectPoint(pts[2], SIMD3(10, 0, 0), "last")
        }
        // 10 / 4 = 2.5 intervals rounds to 3 (half away from zero), so 4 points a third of the
        // edge apart; a floor would give 3 points and a ceiling the same 4.
        let stretched = ec.points(spacing: 4)
        #expect(stretched.count == 4)
        if stretched.count == 4 {
            for (i, p) in stretched.enumerated() {
                expectPoint(p, SIMD3(10.0 * Double(i) / 3.0, 0, 0), "spacing 4, point \(i)")
            }
        }
        #expect(ec.points(spacing: 0).isEmpty)  // spacing must be > 0
        #expect(ec.points(spacing: -1).isEmpty)
    }
}
