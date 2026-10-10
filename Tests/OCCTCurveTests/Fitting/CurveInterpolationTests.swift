import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GeomAPI_Interpolate read back through BRepAdaptor_CompCurve, as the wire bridge
// functions do (Scripts/repro/766-curve-dn-interp-bounded/transcript.txt). The earlier versions
// force-unwrapped inside #expect (`info!.isClosed`, `midPoint!.y > 0`), allowed 0.5 of slack on
// the length, and checked only `> 0` or `> 5` at the midpoint (#766).
@Suite("Curve Interpolation Tests")
struct CurveInterpolationTests {
    @Test("Interpolate through 2 points")
    func interpolateTwoPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 10, 0),
        ]
        guard let wire = Wire.interpolate(through: points) else {
            Issue.record("interpolation failed")
            return
        }
        // A straight line: length sqrt(200).
        #expect(abs((wire.length ?? 0) - 200.0.squareRoot()) < 1e-9)
    }

    @Test("Interpolate through multiple points")
    func interpolateMultiplePoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 5, 0),
            SIMD3(20, 0, 0),
            SIMD3(30, 5, 0),
            SIMD3(40, 0, 0),
        ]
        guard let wire = Wire.interpolate(through: points), let info = wire.curveInfo else {
            Issue.record("interpolation or curve info failed")
            return
        }
        #expect(!info.isClosed)
        // The normalised midpoint is the middle input point.
        #expect(simd_distance(wire.point(at: 0.5) ?? .zero, SIMD3(20, 0, 0)) < 1e-9)
        #expect(abs((wire.length ?? 0) - 47.413493009755058) < 1e-6)
    }

    @Test("Interpolate closed curve")
    func interpolateClosed() {
        // Create points for a closed curve (roughly circular)
        let points: [SIMD3<Double>] = [
            SIMD3(10, 0, 0),
            SIMD3(0, 10, 0),
            SIMD3(-10, 0, 0),
            SIMD3(0, -10, 0),
        ]
        guard let wire = Wire.interpolate(through: points, closed: true),
            let info = wire.curveInfo
        else {
            Issue.record("closed interpolation or curve info failed")
            return
        }
        #expect(info.isClosed)
        #expect(simd_distance(wire.point(at: 0.5) ?? .zero, SIMD3(-10, 0, 0)) < 1e-9)
    }

    @Test("Interpolate with tangent constraints")
    func interpolateWithTangents() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
        ]
        // Start going up, end going down (creates an arc)
        guard
            let wire = Wire.interpolate(
                through: points,
                startTangent: SIMD3(1, 1, 0),  // 45 degrees up
                endTangent: SIMD3(1, -1, 0)  // 45 degrees down
            ),
            let midPoint = wire.point(at: 0.5)
        else {
            Issue.record("interpolation with tangents failed")
            return
        }
        // The curve arcs above the straight line: its midpoint is (5, 1.25, 0).
        #expect(simd_distance(midPoint, SIMD3(5, 1.25, 0)) < 1e-9)
    }

    @Test("Interpolate 3D curve")
    func interpolate3DCurve() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 5),
            SIMD3(20, 0, 10),
            SIMD3(30, 0, 5),
            SIMD3(40, 0, 0),
        ]
        guard let wire = Wire.interpolate(through: points), let midPoint = wire.point(at: 0.5)
        else {
            Issue.record("3D interpolation failed")
            return
        }
        // The normalised midpoint is the middle input point.
        #expect(simd_distance(midPoint, SIMD3(20, 0, 10)) < 1e-9)
    }

    @Test("Interpolate too few points returns nil")
    func interpolateTooFewPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0)  // Only 1 point
        ]
        let wire = Wire.interpolate(through: points)
        #expect(wire == nil)
    }
}
