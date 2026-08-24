import Foundation
import Testing

@testable import OCCTSwift

// MARK: - #493: the two 3D periodic-interpolation entry points

/// The same `GeomAPI_Interpolate` computation is reachable two ways:
/// `Curve3D.interpolatePeriodic(points:tolerance:)` and
/// `Curve3D.interpolate(points:closed:tolerance:)` with `closed: true`. They used to be two
/// independent bridge call sites that had drifted apart in two ways. The periodic one rejected
/// `count < 3` where the general one rejects only `count < 2`, and it hardcoded tolerance `1e-6`
/// with no parameter path to reach any other value. This is the 3D counterpart of the 2D parity
/// suite added for #412 (`Curve2DInterpolatePeriodicParityTests`), which was fixed on its own.
@Suite("Curve3D periodic interpolation entry points agree (#493)")
struct Curve3DInterpolatePeriodicParityTests {

    private static let square: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
    ]

    private func expectSameCurve(
        _ a: Curve3D?, _ b: Curve3D?,
        _ comment: Comment? = nil
    ) {
        #expect(a != nil, comment)
        #expect(b != nil, comment)
        guard let a, let b else { return }
        #expect(a.isClosed == b.isClosed, comment)
        #expect(a.isPeriodic == b.isPeriodic, comment)
        #expect(abs(a.domain.lowerBound - b.domain.lowerBound) < 1e-12, comment)
        #expect(abs(a.domain.upperBound - b.domain.upperBound) < 1e-12, comment)
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            let ua = a.domain.lowerBound + t * (a.domain.upperBound - a.domain.lowerBound)
            let ub = b.domain.lowerBound + t * (b.domain.upperBound - b.domain.lowerBound)
            let pa = a.point(at: ua)
            let pb = b.point(at: ub)
            #expect(abs(pa.x - pb.x) < 1e-9, comment)
            #expect(abs(pa.y - pb.y) < 1e-9, comment)
            #expect(abs(pa.z - pb.z) < 1e-9, comment)
        }
    }

    @Test("Default tolerance: the two entry points produce the same curve")
    func defaultToleranceMatches() {
        expectSameCurve(
            Curve3D.interpolatePeriodic(points: Self.square),
            Curve3D.interpolate(points: Self.square, closed: true))
    }

    @Test("A non-default tolerance is now reachable through interpolatePeriodic")
    func customToleranceIsReachable() {
        for tolerance in [1e-3, 1e-4, 1e-8] {
            expectSameCurve(
                Curve3D.interpolatePeriodic(points: Self.square, tolerance: tolerance),
                Curve3D.interpolate(
                    points: Self.square, closed: true,
                    tolerance: tolerance),
                "tolerance=\(tolerance)")
        }
    }

    /// The point-count floor the two had drifted apart on. OCCT accepts a 2-point periodic
    /// interpolation (it produces a valid out-and-back loop), and the general entry point always
    /// let it through; only the periodic wrapper rejected it at the bridge boundary.
    @Test("A 2-point periodic interpolation is accepted by both entry points")
    func twoPointFloorMatches() {
        let two: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]
        let periodic = Curve3D.interpolatePeriodic(points: two)
        expectSameCurve(periodic, Curve3D.interpolate(points: two, closed: true))
        if let c = periodic {
            #expect(c.isClosed)
            #expect(c.isPeriodic)
        }
    }

    @Test("Both entry points reject a single point")
    func singlePointRejectedByBoth() {
        let one: [SIMD3<Double>] = [SIMD3(1, 2, 3)]
        #expect(Curve3D.interpolatePeriodic(points: one) == nil)
        #expect(Curve3D.interpolate(points: one, closed: true) == nil)
    }

    /// The tolerance is not merely accepted, it reaches `GeomAPI_Interpolate` and changes the
    /// outcome: OCCT treats points closer together than the tolerance as coincident and refuses to
    /// interpolate. With two points 1e-3 apart, the default 1e-6 interpolates and 1e-2 does not:
    /// a distinction no caller could make before `interpolatePeriodic` gained the parameter.
    @Test("The tolerance actually reaches OCCT, it is not just accepted and dropped")
    func toleranceChangesTheOutcome() {
        let nearCoincident: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10.001, 0, 0),
        ]
        #expect(Curve3D.interpolatePeriodic(points: nearCoincident) != nil)
        #expect(Curve3D.interpolatePeriodic(points: nearCoincident, tolerance: 1e-9) != nil)
        #expect(Curve3D.interpolatePeriodic(points: nearCoincident, tolerance: 1e-2) == nil)
        // ... and the general entry point draws the line in the same place.
        #expect(Curve3D.interpolate(points: nearCoincident, closed: true, tolerance: 1e-2) == nil)
        #expect(Curve3D.interpolate(points: nearCoincident, closed: true, tolerance: 1e-9) != nil)
    }

    /// A non-planar loop, to make sure the shared path is not accidentally flattening z.
    @Test("A non-planar loop agrees through both entry points")
    func nonPlanarLoopMatches() {
        let helixish: [SIMD3<Double>] = [
            SIMD3(5, 0, 0), SIMD3(0, 5, 2), SIMD3(-5, 0, 4), SIMD3(0, -5, 2),
        ]
        expectSameCurve(
            Curve3D.interpolatePeriodic(points: helixish, tolerance: 1e-5),
            Curve3D.interpolate(points: helixish, closed: true, tolerance: 1e-5))
    }
}
