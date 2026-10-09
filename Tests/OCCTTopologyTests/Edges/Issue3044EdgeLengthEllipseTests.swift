import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Ground truth that shares no code with the bridge: Simpson integration of the ellipse speed
/// over a quarter period, times four.
private func trueEllipsePerimeter(a: Double, b: Double) -> Double {
    let n = 200_000
    let h = (Double.pi / 2) / Double(n)
    func speed(_ t: Double) -> Double {
        (a * a * sin(t) * sin(t) + b * b * cos(t) * cos(t)).squareRoot()
    }
    var sum = speed(0) + speed(Double.pi / 2)
    for i in 1..<n {
        sum += speed(Double(i) * h) * (i % 2 == 0 ? 2 : 4)
    }
    return 4 * sum * h / 3
}

@Suite("Edge.length adaptive arc length, Issue #3044") struct Issue3044EdgeLengthEllipseTests {
    // One test walking a list rather than @Test(arguments:), to keep clear of #1057.
    @Test("Elliptical edge length matches the true perimeter, Wire.length and Curve2D.length")
    func ellipseEdgeLength() {
        let cases: [(a: Double, b: Double)] = [(3, 2), (10, 5), (20, 5), (10, 1)]
        for (a, b) in cases {
            let truth = trueEllipsePerimeter(a: a, b: b)
            guard let curve = Curve2D.ellipse(center: .zero, majorRadius: a, minorRadius: b),
                let wire = Wire.fromCurve2D(curve)
            else {
                Issue.record("could not build \(a) x \(b) ellipse")
                continue
            }
            let edges = wire.edges()
            #expect(edges.count == 1)
            if let edge = edges.first {
                #expect(
                    abs(edge.length - truth) < truth * 1e-8,
                    "edge \(a) x \(b): \(edge.length) vs \(truth)")
                if let wireLength = wire.length {
                    #expect(abs(edge.length - wireLength) < truth * 1e-8)
                }
            }
            if let curveLength = curve.length {
                #expect(abs(curveLength - truth) < truth * 1e-8)
            }
        }
    }

    @Test("Circle and line edges stay exact")
    func controls() {
        if let circle = Wire.circle(radius: 5), let edge = circle.edges().first {
            #expect(abs(edge.length - 2 * Double.pi * 5) < 1e-9)
        } else {
            Issue.record("no circle edge")
        }
        if let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)),
            let edge = line.edges().first
        {
            #expect(abs(edge.length - 5) < 1e-12)
        } else {
            Issue.record("no line edge")
        }
    }

    @Test("A quarter arc of an ellipse edge is measured too")
    func quarterArc() {
        if let arc = Curve2D.arcOfEllipse(
            center: .zero, majorRadius: 10, minorRadius: 1, startAngle: 0, endAngle: .pi / 2),
            let wire = Wire.fromCurve2D(arc), let edge = wire.edges().first
        {
            let truth = trueEllipsePerimeter(a: 10, b: 1) / 4
            #expect(abs(edge.length - truth) < truth * 1e-8)
        }
    }
}
