import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every expected value is what Geom_BezierCurve reports after the same edit
// (Scripts/repro/766-curve-bezier-curve3d/transcript.txt). The earlier versions wrapped each body
// in `if let`, and most checked only the Bool the bridge returns, which is `true` whether or not
// the edit happened, so a bridge that skipped Segment, InsertPoleAfter or SetWeight passed (#766).
@Suite("Bezier Curve Manipulation Tests")
struct BezierCurveManipulationTests {
    private static let cubic: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
    ]

    private static func make(_ poles: [SIMD3<Double>] = cubic) -> Curve3D? {
        let c = Curve3D.bezier(poles: poles)
        if c == nil { Issue.record("Bezier curve not built") }
        return c
    }

    private static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        simd_distance(a, b) < 1e-9
    }

    @Test func degreeAndPoleCount() {
        guard let bez = Self.make() else { return }
        #expect(bez.bezier.degree == 3)
        #expect(bez.bezier.poleCount == 4)
    }

    @Test func isRational() {
        guard let bez = Self.make() else { return }
        #expect(!bez.bezier.isRational)
    }

    @Test func getPole() {
        guard let bez = Self.make() else { return }
        for (i, p) in Self.cubic.enumerated() {
            #expect(Self.near(bez.bezier.pole(at: i + 1), p))
        }
    }

    @Test func setPole() {
        guard let bez = Self.make() else { return }
        #expect(bez.bezier.setPole(at: 2, to: SIMD3(3, 8, 0)))
        #expect(Self.near(bez.bezier.pole(at: 2), SIMD3(3, 8, 0)))
        #expect(Self.near(bez.bezier.pole(at: 1), SIMD3(0, 0, 0)))
        #expect(Self.near(bez.bezier.pole(at: 3), SIMD3(7, 5, 0)))
    }

    @Test func segment() {
        guard let bez = Self.make() else { return }
        #expect(bez.bezier.segment(u1: 0.25, u2: 0.75))
        // The piece between C(0.25) and C(0.75), reparameterised onto [0, 1].
        #expect(bez.bezier.poleCount == 4)
        #expect(Self.near(bez.bezier.pole(at: 1), SIMD3(2.40625, 2.8125, 0)))
        #expect(Self.near(bez.bezier.pole(at: 2), SIMD3(4.09375, 4.0625, 0)))
        #expect(Self.near(bez.bezier.pole(at: 3), SIMD3(5.90625, 4.0625, 0)))
        #expect(Self.near(bez.bezier.pole(at: 4), SIMD3(7.59375, 2.8125, 0)))
        #expect(Self.near(bez.point(at: 0.5), SIMD3(5, 3.75, 0)))
    }

    @Test func increaseDegree() {
        guard let bez = Self.make() else { return }
        #expect(bez.bezier.increaseDegree(to: 5))
        #expect(bez.bezier.degree == 5)
        #expect(bez.bezier.poleCount == 6)
        #expect(Self.near(bez.bezier.pole(at: 2), SIMD3(1.8, 3, 0)))
        // Degree elevation keeps the shape.
        #expect(Self.near(bez.point(at: 0.3), SIMD3(2.916, 3.15, 0)))
    }

    @Test func insertPoleAfter() {
        guard let bez = Self.make() else { return }
        #expect(bez.bezier.insertPoleAfter(index: 2, point: SIMD3(5, 6, 0)))
        #expect(bez.bezier.poleCount == 5)
        #expect(bez.bezier.degree == 4)
        #expect(Self.near(bez.bezier.pole(at: 3), SIMD3(5, 6, 0)))
        #expect(Self.near(bez.bezier.pole(at: 4), SIMD3(7, 5, 0)))
    }

    @Test func removePole() {
        guard
            let bez = Self.make([
                SIMD3(0, 0, 0), SIMD3(3, 5, 0), SIMD3(5, 6, 0), SIMD3(7, 5, 0), SIMD3(10, 0, 0),
            ])
        else { return }
        #expect(bez.bezier.removePole(at: 3))
        #expect(bez.bezier.poleCount == 4)
        #expect(Self.near(bez.bezier.pole(at: 3), SIMD3(7, 5, 0)))
    }

    @Test func setWeight() {
        guard let bez = Self.make() else { return }
        #expect(bez.bezier.setWeight(at: 2, to: 2.0))
        #expect(bez.bezier.isRational)
        #expect(bez.bezierWeights == [1, 2, 1, 1])
    }
}
