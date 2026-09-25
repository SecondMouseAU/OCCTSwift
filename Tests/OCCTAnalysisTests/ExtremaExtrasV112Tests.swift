import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values probed on the pinned kernel: Scripts/repro/766-extrema-extras-v112/transcript.txt.
//
// Before #766's execution pass each fixture sat inside `if let`, so a constructor returning nil
// passed the test with nothing asserted, and `locateOnSurface` also wrapped the result in `if
// let`, so a bridge answering nil every time passed it. The loose `< 1.5` and `< 0.1` bounds are
// replaced by the measured parameters and distances, which also pins the parameter (u, v) that
// the old tests never read.
@Suite("Extrema extras v0.112")
struct ExtremaExtrasV112Tests {

    @Test func locateOnCurve() {
        guard
            let circle = Curve3D.circle(
                center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("Curve3D.circle returned nil")
            return
        }
        guard let r = circle.locateNearestPoint(SIMD3(6, 0, 0), initParam: 0) else {
            Issue.record("locateNearestPoint returned nil on a readable circle")
            return
        }
        // (6, 0, 0) is 1 outside the circle at parameter 0.
        #expect(abs(r.parameter) < 1e-9, "got \(r.parameter)")
        #expect(abs(r.distance - 1) < 1e-9, "got \(r.distance)")
    }

    @Test func projectPointOnCurve() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("Curve3D.line returned nil")
            return
        }
        let results = line.projectPointAll(SIMD3(5, 3, 0))
        // An unbounded line has exactly one perpendicular foot.
        #expect(results.count == 1)
        guard let first = results.first else { return }
        #expect(abs(first.parameter - 5) < 1e-9, "got \(first.parameter)")
        #expect(abs(first.distance - 3) < 1e-9, "got \(first.distance)")
    }

    @Test func locateOnSurface() {
        guard let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) else {
            Issue.record("Surface.plane returned nil")
            return
        }
        guard let r = surf.locateNearestPoint(SIMD3(5, 3, 10), initU: 0, initV: 0) else {
            Issue.record("locateNearestPoint returned nil on a plane")
            return
        }
        // The plane's X direction is +X, so the foot (5, 3, 0) sits at (u, v) = (5, 3).
        #expect(abs(r.u - 5) < 1e-9, "got u=\(r.u)")
        #expect(abs(r.v - 3) < 1e-9, "got v=\(r.v)")
        #expect(abs(r.distance - 10) < 1e-9, "got \(r.distance)")
    }

    @Test func projectPointOnSurface() {
        guard let surf = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) else {
            Issue.record("Surface.sphere returned nil")
            return
        }
        let results = surf.projectPointAll(SIMD3(10, 0, 0))
        // Two extrema on the X axis: the near side (u = 0) at 5 and the far side (u = pi) at 15.
        #expect(results.count == 2)
        guard results.count == 2 else { return }
        #expect(abs(results[0].u) < 1e-9)
        #expect(abs(results[0].v) < 1e-9)
        #expect(abs(results[0].distance - 5) < 1e-9, "got \(results[0].distance)")
        #expect(abs(results[1].u - Double.pi) < 1e-9)
        #expect(abs(results[1].distance - 15) < 1e-9, "got \(results[1].distance)")
    }
}
