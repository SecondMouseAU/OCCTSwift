import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Ellipse Arc Tests")
struct EllipseArcTests {
    // Pinned to GC_MakeArcOfEllipse on the same inputs
    // (Scripts/repro/766-curve-edgecurve-ellipsearc/transcript.txt). The earlier versions sat
    // inside `if let` with 0.1 of slack, and arcProperties checked `start.x > 9`, `end.y > 4` (#766).

    @Test("Arc of ellipse from angles")
    func arcFromAngles() {
        // Ellipse with major radius 10, minor radius 5 in XY plane
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi / 2
        )
        guard let arc else {
            Issue.record("arc not built")
            return
        }
        // Start on the major axis (10, 0, 0), end on the minor axis (0, 5, 0).
        #expect(simd_distance(arc.startPoint, SIMD3(10, 0, 0)) < 1e-12)
        #expect(simd_distance(arc.endPoint, SIMD3(0, 5, 0)) < 1e-12)
    }

    @Test("Arc of ellipse between two points")
    func arcBetweenPoints() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            from: SIMD3(10, 0, 0),
            to: SIMD3(-10, 0, 0)
        )
        guard let arc else {
            Issue.record("arc not built")
            return
        }
        #expect(simd_distance(arc.startPoint, SIMD3(10, 0, 0)) < 1e-12)
        #expect(simd_distance(arc.endPoint, SIMD3(-10, 0, 0)) < 1e-12)
        // Counterclockwise from (10, 0, 0): the arc passes through (0, 5, 0), not (0, -5, 0).
        let d = arc.domain
        #expect(simd_distance(arc.point(at: (d.lowerBound + d.upperBound) / 2), SIMD3(0, 5, 0)) < 1e-12)
    }

    @Test("Full semi-ellipse arc")
    func semiEllipse() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi
        )
        guard let arc else {
            Issue.record("arc not built")
            return
        }
        // Start at (10,0,0), end at (-10,0,0)
        #expect(simd_distance(arc.startPoint, SIMD3(10, 0, 0)) < 1e-12)
        #expect(simd_distance(arc.endPoint, SIMD3(-10, 0, 0)) < 1e-12)
    }

    @Test("Ellipse arc properties")
    func arcProperties() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi / 2
        )
        guard let arc else {
            Issue.record("arc not built")
            return
        }
        #expect(!arc.isClosed)
        #expect(arc.domain == 0...(Double.pi / 2))
        // The parameter midpoint is (10 cos pi/4, 5 sin pi/4, 0).
        #expect(
            simd_distance(arc.point(at: Double.pi / 4), SIMD3(7.0710678118654755, 3.5355339059327373, 0))
                < 1e-12)
    }
}
