import Foundation
import Testing

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

@Suite("Shape.totalEdgeLength adaptive arc length, Issue #3074")
struct Issue3074TotalEdgeLengthTests {
    // One test walking a list rather than @Test(arguments:), to keep clear of #1057.
    @Test("An elliptical shape's total edge length matches the true perimeter and Edge.length")
    func ellipseTotalEdgeLength() {
        let cases: [(a: Double, b: Double)] = [(3, 2), (10, 5), (20, 5), (10, 1)]
        for (a, b) in cases {
            let truth = trueEllipsePerimeter(a: a, b: b)
            guard let curve = Curve2D.ellipse(center: .zero, majorRadius: a, minorRadius: b),
                let wire = Wire.fromCurve2D(curve),
                let shape = Shape.fromWire(wire)
            else {
                Issue.record("could not build \(a) x \(b) ellipse")
                continue
            }
            // Measured agreement with the Simpson reference is 2e-14 to 1.6e-13 relative (and
            // exactly 0 against the summed Edge.length, which takes the same path), so 1e-10 leaves
            // a margin of about 600x. The reference limits it: composite Simpson over 200k
            // intervals is good to about 1e-14 here. The bridge's own target is 1e-12.
            #expect(
                abs(shape.totalEdgeLength - truth) < truth * 1e-10,
                "shape \(a) x \(b): \(shape.totalEdgeLength) vs \(truth)")
            let summed = shape.edges().reduce(0.0) { $0 + $1.length }
            #expect(abs(shape.totalEdgeLength - summed) < truth * 1e-10)
        }
    }

    @Test("Circle, line and rectangle wires stay exact")
    func wireControls() {
        if let circle = Wire.circle(radius: 5), let shape = Shape.fromWire(circle) {
            #expect(abs(shape.totalEdgeLength - 2 * Double.pi * 5) < 1e-9)
        } else {
            Issue.record("no circle")
        }
        if let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)),
            let shape = Shape.fromWire(line)
        {
            #expect(abs(shape.totalEdgeLength - 5) < 1e-12)
        } else {
            Issue.record("no line")
        }
        if let rect = Wire.rectangle(width: 10, height: 20), let shape = Shape.fromWire(rect) {
            #expect(abs(shape.totalEdgeLength - 60) < 1e-12)
        } else {
            Issue.record("no rectangle")
        }
    }

    @Test("A shared edge is still counted once per face, as before")
    func sharedEdgesCountPerOccurrence() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("no box")
            return
        }
        let distinct = box.edges().reduce(0.0) { $0 + $1.length }
        #expect(abs(distinct - 40) < 1e-9, "12 distinct edges: 4 each of 2, 3 and 5")
        // Each of the 12 edges bounds two faces, so a walk over every occurrence reads twice.
        #expect(abs(box.totalEdgeLength - 80) < 1e-9, "got \(box.totalEdgeLength)")
    }

    @Test("Degenerate edges add nothing and a seam edge counts once per occurrence")
    func degenerateAndSeamEdges() {
        guard let sphere = Shape.sphere(radius: 4) else {
            Issue.record("no sphere")
            return
        }
        let edges = sphere.edges()
        let measured = edges.filter { $0.length > 0 }
        // A sphere has one meridian seam, used twice by its single face, and two degenerate pole
        // edges that measure 0. Half a great circle is pi r; counted twice that is 2 pi r.
        #expect(measured.count == 1, "one non-degenerate edge, got \(measured.count)")
        #expect(abs(sphere.totalEdgeLength - 2 * Double.pi * 4) < 1e-9)
    }
}
