import Foundation
import Testing

@testable import OCCTSwift

/// Ground truth that shares no code with the bridge: Simpson integration of the ellipse speed
/// over a quarter period, times four.
private func simpsonEllipsePerimeter(a: Double, b: Double) -> Double {
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

/// `Shape.analyze(tolerance:)` counts a small edge by the adaptive arc length (#3074).
///
/// `BRepGProp::LinearProperties` applies one fixed Gauss rule to a one-interval curve and reads a
/// 10 x 1 ellipse as 41.2431578703 against a true 40.6397418010, so a tolerance between the two
/// classified the edge wrongly. The count now measures as `Edge.length` does (#3044).
@Suite("Issue 3074: analyze small-edge count uses the adaptive length")
struct Issue3074AnalyzeSmallEdgeAdaptive {

    private func ellipseWire() throws -> Wire {
        let curve = try #require(
            Curve2D.ellipse(center: .zero, majorRadius: 10, minorRadius: 1))
        return try #require(Wire.fromCurve2D(curve))
    }

    private func ellipseEdge() throws -> Shape {
        let wire = try ellipseWire()
        return try #require(Shape.fromWire(wire))
    }

    private func count(_ shape: Shape, _ tolerance: Double) throws -> Int {
        let report = try #require(shape.analyze(tolerance: tolerance))
        return report.smallEdgeCount
    }

    @Test("a tolerance between the true and the single-rule length classifies by the true one")
    func toleranceInsideTheBand() throws {
        let edge = try ellipseEdge()
        let truth = simpsonEllipsePerimeter(a: 10, b: 1)
        #expect(abs(truth - 40.6397418010) < 1e-8)
        let wire = try ellipseWire()
        let edgeLength = try #require(wire.edges().first?.length)
        #expect(abs(edgeLength - truth) < truth * 1e-8)

        // 40.6397 < 41.0 < 41.2432: short by its true length, so counted. The single rule read
        // 41.2432 >= 41.0 and did not count it.
        #expect(try count(edge, 41.0) == 1)
        // Just under the true length: not counted either way.
        #expect(try count(edge, 40.5) == 0)
    }

    @Test("a tolerance far from the length classifies the same as before")
    func toleranceFarFromTheLength() throws {
        let edge = try ellipseEdge()
        #expect(try count(edge, 100) == 1)
        #expect(try count(edge, 1) == 0)
    }

    @Test("a circle and a line edge classify by their exact length")
    func circleAndLineControls() throws {
        let circleWire = try #require(Wire.circle(radius: 5))
        let circle = try #require(Shape.fromWire(circleWire))
        let perimeter = 2 * Double.pi * 5
        #expect(try count(circle, perimeter + 0.01) == 1)
        #expect(try count(circle, perimeter - 0.01) == 0)

        let lineWire = try #require(Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)))
        let line = try #require(Shape.fromWire(lineWire))
        #expect(try count(line, 5.01) == 1)
        #expect(try count(line, 4.99) == 0)
    }
}
