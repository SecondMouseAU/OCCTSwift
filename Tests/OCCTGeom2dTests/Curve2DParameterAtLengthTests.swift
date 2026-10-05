import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Issue #37: Curve2D.parameterAtLength

// Every test requires its values and pins them to a closed form: the parameter of a segment is its
// length along the line, the parameter of a circular arc is its angle, so an arc of radius r over an
// angle a is r * a long. `GCPnts_AbscissaPoint`'s own answers for the same curves are in
// `Scripts/repro/766-geom2d-param-at-length-point2d/transcript.txt` and
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
@Suite("Curve2D parameterAtLength Tests")
struct Curve2DParameterAtLengthTests {

    @Test("Parameter at full arc length of a circle arc")
    func parameterAtFullArcLength() throws {
        // Quarter arc of radius 10 has length pi/2 * 10 ≈ 15.708
        let arc = try #require(
            Curve2D.arcOfCircle(
                center: .zero, radius: 10,
                startAngle: 0, endAngle: .pi / 2))
        let expectedLength: Double = Double.pi / 2.0 * 10.0
        let totalLen = try #require(arc.length)
        #expect(abs(totalLen - expectedLength) < 1e-9)
        // The parameter of an arc is its angle, so half the length is pi/4, the arc's midpoint.
        let param = try #require(arc.parameterAtLength(totalLen / 2))
        #expect(abs(param - Double.pi / 4) < 1e-9)
        let pt = arc.point(at: param)
        let expectedX: Double = 10 * cos(Double.pi / 4)
        let expectedY: Double = 10 * sin(Double.pi / 4)
        #expect(simd_distance(pt, SIMD2(expectedX, expectedY)) < 1e-9)
    }

    @Test("Parameter at length on an arc that does not start at angle 0")
    func parameterAtLengthOnOffsetArc() throws {
        // From pi/6 to pi/6 + pi/2 about (1, 1). Half the length lands at pi/6 + pi/4, which is
        // not length / radius, so a parameter that ignored the arc's start would show here.
        let start: Double = Double.pi / 6
        let arc = try #require(
            Curve2D.arcOfCircle(
                center: SIMD2(1, 1), radius: 10,
                startAngle: start, endAngle: start + Double.pi / 2))
        let total = try #require(arc.length)
        #expect(abs(total - 5 * Double.pi) < 1e-9)

        let half = try #require(arc.parameterAtLength(total / 2))
        let halfAngle: Double = start + Double.pi / 4
        #expect(abs(half - halfAngle) < 1e-9)
        let expectedX: Double = 1 + 10 * cos(halfAngle)
        let expectedY: Double = 1 + 10 * sin(halfAngle)
        #expect(simd_distance(arc.point(at: half), SIMD2(expectedX, expectedY)) < 1e-9)

        // The documented identity: the whole length lands on the end of the domain.
        let full = try #require(arc.parameterAtLength(total))
        #expect(abs(full - arc.domain.upperBound) < 1e-9)
    }

    @Test("Parameter at zero length returns start parameter")
    func parameterAtZeroLength() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let param = try #require(seg.parameterAtLength(0))
        #expect(abs(param) < 1e-12)
        let pt = seg.point(at: param)
        #expect(simd_distance(pt, SIMD2(0, 0)) < 1e-12)

        // Zero travel returns the starting parameter, wherever that is.
        let later = try #require(seg.parameterAtLength(0, from: 4))
        #expect(abs(later - 4) < 1e-12)
    }

    @Test("Parameter at full length of a segment")
    func parameterAtFullSegmentLength() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let totalLen = try #require(seg.length)
        let param = try #require(seg.parameterAtLength(totalLen))
        // The whole length lands on the end of the domain, which is 10 for this segment.
        #expect(abs(param - seg.domain.upperBound) < 1e-9)
        let pt = seg.point(at: param)
        #expect(abs(pt.x - 10.0) < 1e-9)
        #expect(abs(pt.y) < 1e-9)
    }

    @Test("Parameter at length along a diagonal segment is measured in length, not in x")
    func parameterAtLengthOnDiagonalSegment() throws {
        // (1, 2) to (4, 6) is a 3-4-5 triangle: the length is 5 and the parameter is the length.
        let seg = try #require(Curve2D.segment(from: SIMD2(1, 2), to: SIMD2(4, 6)))
        let total = try #require(seg.length)
        #expect(abs(total - 5) < 1e-12)

        let half = try #require(seg.parameterAtLength(2.5))
        #expect(abs(half - 2.5) < 1e-12)
        #expect(simd_distance(seg.point(at: half), SIMD2(2.5, 4)) < 1e-12)

        let full = try #require(seg.parameterAtLength(total))
        #expect(abs(full - seg.domain.upperBound) < 1e-12)
        #expect(simd_distance(seg.point(at: full), SIMD2(4, 6)) < 1e-12)
    }

    @Test("Parameter at length from non-start parameter")
    func parameterAtLengthFromMidpoint() throws {
        // 20-unit horizontal segment; measure 5 units starting from parameter at x=5
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0)))
        let midParam = seg.domain.lowerBound + (seg.domain.upperBound - seg.domain.lowerBound) / 2
        let param = try #require(seg.parameterAtLength(5, from: midParam))
        #expect(abs(param - 15) < 1e-9)
        let pt = seg.point(at: param)
        #expect(abs(pt.x - 15.0) < 1e-9)

        // A negative distance travels backwards from the same start.
        let back = try #require(seg.parameterAtLength(-5, from: midParam))
        #expect(abs(back - 5) < 1e-9)
    }

    @Test("parameterAtLength extrapolates past the end and answers nil for NaN")
    func parameterAtLengthFailure() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        // A trimmed line has no failure past its end: GCPnts_AbscissaPoint extrapolates along the
        // basis line and returns u = 1000 for a distance of 1000, and the bridge keeps that answer
        // on purpose (`occtAdaptorParameterAtLength`, #603), as `Curve3D.parameterAtLength`'s
        // documentation says. The 2D doc comment promises nil here, which #3034 records, so this
        // pins what both the bridge and the 3D documentation state.
        #expect(seg.parameterAtLength(1000) == 1000)
        // Backwards past the start extrapolates the same way.
        #expect(seg.parameterAtLength(-5) == -5)
        // A NaN distance or start has no answer. Infinity is left unpinned: it answers differently
        // by curve type and sign, which is also #3034.
        #expect(seg.parameterAtLength(.nan) == nil)
        #expect(seg.parameterAtLength(5, from: .nan) == nil)
    }

    // The composite Simpson integral of |C'(u)| over [a, b], from the curve's own first derivative:
    // a length that reads nothing from the bridge's length or parameter-at-length functions.
    private func simpsonLength(_ curve: Curve2D, _ a: Double, _ b: Double) -> Double {
        let panels = 4000
        let h = (b - a) / Double(panels)
        func speed(_ u: Double) -> Double { simd_length(curve.d1(at: u).tangent) }
        var sum = speed(a) + speed(b)
        for i in 1..<panels {
            let weight: Double = i % 2 == 1 ? 4 : 2
            sum += weight * speed(a + Double(i) * h)
        }
        return sum * h / 3
    }

    @Test("Parameter at length on an ellipse follows its symmetry and an independent integral")
    func parameterAtLengthOnAnEllipse() throws {
        // An ellipse has no closed-form perimeter, so two independent things stand in for one.
        // Its four quarters are congruent, so a quarter of the length lands on the next vertex:
        // pi/2, pi, 3 pi/2 and 2 pi. And the length is checked against a Simpson integral of the
        // curve's own speed. A length that is off by a thousandth of a percent fails the first
        // check; #603 measured a whole ellipse up to 1.7% long under the single fixed-order Gauss
        // rule that carried patch 0021 replaced.
        let e = try #require(Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 5))
        let total = try #require(e.length)
        let reference = simpsonLength(e, 0, 2 * Double.pi)
        #expect(abs(total - reference) < 1e-9, "length \(total), integral \(reference)")

        for quarter in 1...4 {
            let u = try #require(e.parameterAtLength(total * Double(quarter) / 4))
            let vertex: Double = Double(quarter) * Double.pi / 2
            #expect(abs(u - vertex) < 1e-9, "\(quarter) quarters: \(u), expected \(vertex)")
        }

        // Off a vertex there is no symmetry to lean on, so the arc up to the answer is integrated.
        let target: Double = total * 0.3
        let u = try #require(e.parameterAtLength(target))
        #expect(abs(simpsonLength(e, 0, u) - target) < 1e-9)

        // From the minor vertex a quarter on lands on the next major one, and backwards from there
        // returns.
        let onward = try #require(e.parameterAtLength(total / 4, from: Double.pi / 2))
        #expect(abs(onward - Double.pi) < 1e-9)
        let back = try #require(e.parameterAtLength(-total / 4, from: Double.pi))
        #expect(abs(back - Double.pi / 2) < 1e-9)
    }

    @Test("Trim curve to exact arc length using parameterAtLength")
    func trimToArcLength() throws {
        // Create a 20-unit segment, trim to exactly 7 units from start
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(20, 0)))
        let first = seg.domain.lowerBound
        let endParam = try #require(seg.parameterAtLength(7, from: first))
        let trimmed = try #require(seg.trimmed(from: first, to: endParam))
        let len = try #require(trimmed.length)
        #expect(abs(len - 7.0) < 1e-9)
        #expect(simd_distance(trimmed.point(at: trimmed.domain.lowerBound), SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(trimmed.point(at: trimmed.domain.upperBound), SIMD2(7, 0)) < 1e-9)

        // Starting part-way along, the same seven units run from x = 5 to x = 12.
        let mid = try #require(seg.parameterAtLength(5, from: first))
        let end = try #require(seg.parameterAtLength(7, from: mid))
        let piece = try #require(seg.trimmed(from: mid, to: end))
        let pieceLen = try #require(piece.length)
        #expect(abs(pieceLen - 7.0) < 1e-9)
        #expect(simd_distance(piece.point(at: piece.domain.lowerBound), SIMD2(5, 0)) < 1e-9)
        #expect(simd_distance(piece.point(at: piece.domain.upperBound), SIMD2(12, 0)) < 1e-9)
    }
}
