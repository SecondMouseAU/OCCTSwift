import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Simpson integral of the ellipse arc x = a cos t, y = b sin t over [t0, t1].
///
/// Shares no code with the bridge. Returns the arc length and the length-weighted centroid.
private func simpsonArc(a: Double, b: Double, t0: Double, t1: Double) -> (
    length: Double, cx: Double, cy: Double
) {
    let n = 400_000
    let h = (t1 - t0) / Double(n)
    var len = 0.0
    var mx = 0.0
    var my = 0.0
    for i in 0...n {
        let t = t0 + Double(i) * h
        let w = (i == 0 || i == n) ? 1.0 : (i % 2 == 0 ? 2.0 : 4.0)
        let ds = (a * a * sin(t) * sin(t) + b * b * cos(t) * cos(t)).squareRoot() * w * h / 3
        len += ds
        mx += a * cos(t) * ds
        my += b * sin(t) * ds
    }
    return (len, mx / len, my / len)
}

@Suite("Shape.linearProperties adaptive length and centroid, Issue #3074")
struct Issue3074LinearPropertiesEllipseTests {
    // One test walking a list rather than @Test(arguments:), to keep clear of #1057.
    @Test("A full ellipse reads its true length and its centre as the centroid")
    func fullEllipse() {
        let cases: [(a: Double, b: Double)] = [(3, 2), (10, 5), (20, 5), (10, 1)]
        for (a, b) in cases {
            let truth = simpsonArc(a: a, b: b, t0: 0, t1: 2 * Double.pi).length
            guard let curve = Curve2D.ellipse(center: .zero, majorRadius: a, minorRadius: b),
                let wire = Wire.fromCurve2D(curve), let shape = Shape.fromWire(wire),
                let lp = shape.linearProperties()
            else {
                Issue.record("could not measure \(a) x \(b) ellipse")
                continue
            }
            #expect(abs(lp.length - truth) < truth * 1e-8, "\(a) x \(b): \(lp.length) vs \(truth)")
            // By symmetry the centroid is the centre; the single Gauss rule put it 0.165 off.
            #expect(abs(lp.centerOfMass.x) < 1e-8, "\(a) x \(b): cx \(lp.centerOfMass.x)")
            #expect(abs(lp.centerOfMass.y) < 1e-8, "\(a) x \(b): cy \(lp.centerOfMass.y)")
            #expect(abs(lp.centerOfMass.z) < 1e-8)
        }
    }

    @Test("Ellipse arcs match a Simpson length and centroid")
    func ellipseArcs() {
        let spans: [(Double, Double)] = [(0, .pi), (0, .pi / 2), (0.3, 2.0)]
        for (t0, t1) in spans {
            let ref = simpsonArc(a: 10, b: 1, t0: t0, t1: t1)
            guard
                let arc = Curve2D.arcOfEllipse(
                    center: .zero, majorRadius: 10, minorRadius: 1, startAngle: t0, endAngle: t1),
                let wire = Wire.fromCurve2D(arc), let shape = Shape.fromWire(wire),
                let lp = shape.linearProperties()
            else {
                Issue.record("could not measure arc \(t0)...\(t1)")
                continue
            }
            #expect(abs(lp.length - ref.length) < ref.length * 1e-8)
            #expect(abs(lp.centerOfMass.x - ref.cx) < 1e-8, "cx \(lp.centerOfMass.x) vs \(ref.cx)")
            #expect(abs(lp.centerOfMass.y - ref.cy) < 1e-8, "cy \(lp.centerOfMass.y) vs \(ref.cy)")
        }
    }

    @Test("Lines, circles and a box keep their exact length and centroid")
    func controls() {
        if let rect = Wire.rectangle(width: 10, height: 20), let shape = Shape.fromWire(rect),
            let lp = shape.linearProperties()
        {
            #expect(abs(lp.length - 60) < 1e-12)
            #expect(simd_length(lp.centerOfMass) < 1e-9)
        } else {
            Issue.record("no rectangle")
        }
        if let circle = Wire.circle(radius: 5), let shape = Shape.fromWire(circle),
            let lp = shape.linearProperties()
        {
            #expect(abs(lp.length - 2 * Double.pi * 5) < 1e-9)
            #expect(simd_length(lp.centerOfMass) < 1e-9)
        } else {
            Issue.record("no circle")
        }
        if let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0)),
            let shape = Shape.fromWire(line), let lp = shape.linearProperties()
        {
            #expect(abs(lp.length - 5) < 1e-12)
            #expect(simd_length(lp.centerOfMass - SIMD3(1.5, 2, 0)) < 1e-12)
        } else {
            Issue.record("no line")
        }
        if let box = Shape.box(width: 2, height: 3, depth: 5), let lp = box.linearProperties() {
            #expect(abs(lp.length - 80) < 1e-9, "each edge counted once per face")
            #expect(simd_length(lp.centerOfMass) < 1e-9, "Shape.box is centred on the origin")
        } else {
            Issue.record("no box")
        }
    }

    @Test("A translated ellipse carries its centroid with it")
    func translatedEllipse() {
        if let curve = Curve2D.ellipse(center: SIMD2(7, -3), majorRadius: 10, minorRadius: 1),
            let wire = Wire.fromCurve2D(curve), let shape = Shape.fromWire(wire),
            let lp = shape.linearProperties()
        {
            #expect(abs(lp.centerOfMass.x - 7) < 1e-8)
            #expect(abs(lp.centerOfMass.y + 3) < 1e-8)
        } else {
            Issue.record("no translated ellipse")
        }
    }
}
