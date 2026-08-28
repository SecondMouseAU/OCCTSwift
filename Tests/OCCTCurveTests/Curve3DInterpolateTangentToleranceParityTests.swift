import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `interpolate(points:startTangent:endTangent:)` used to be shadowed by a second, later-added
/// overload of the same name that lacked a `tolerance` parameter entirely: Swift's overload
/// resolution always prefers the exact-arity match, so the ordinary 3-argument call could never
/// reach `interpolate(points:startTangent:endTangent:tolerance:)`'s `tolerance` knob. The
/// duplicate overload (and its separate bridge implementation) is gone; there is now exactly one
/// `interpolate(points:startTangent:endTangent:...)`, so the bare 3-argument call and an explicit
/// `tolerance:` argument reach the same code path.

@Suite("Curve3D.interpolate tangent-tolerance reachability (#400)")
struct Curve3DInterpolateTangentToleranceParityTests {

    private static let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 5, 5), SIMD3(10, 0, 0)]
    private static let startTangent = SIMD3<Double>(1, 1, 1)
    private static let endTangent = SIMD3<Double>(1, -1, -1)

    @Test("Bare 3-arg call matches an explicit default-tolerance call exactly")
    func bareCallMatchesExplicitDefaultTolerance() {
        let bare = Curve3D.interpolate(
            points: Self.points,
            startTangent: Self.startTangent,
            endTangent: Self.endTangent)
        let explicitDefault = Curve3D.interpolate(
            points: Self.points,
            startTangent: Self.startTangent,
            endTangent: Self.endTangent,
            tolerance: 1e-6)
        #expect(bare != nil)
        #expect(explicitDefault != nil)
        if let a = bare, let b = explicitDefault {
            #expect(a.domain.lowerBound == b.domain.lowerBound)
            #expect(a.domain.upperBound == b.domain.upperBound)
            for t in stride(
                from: a.domain.lowerBound, through: a.domain.upperBound,
                by: (a.domain.upperBound - a.domain.lowerBound) / 8)
            {
                #expect(simd_distance(a.point(at: t), b.point(at: t)) < 1e-12)
            }
        }
    }

    @Test("tolerance: is reachable and actually governs the minimum inter-point distance")
    func toleranceParameterIsReachableAndEffective() {
        // Two points 5e-7 apart: farther than 1e-9, but not farther than the 1e-6 default.
        let closePoints: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(0, 0, 5e-7), SIMD3(10, 0, 0)]
        let tan = SIMD3<Double>(1, 0, 0)

        // Default tolerance (bare call): the two near-coincident points are too close, so
        // GeomAPI_Interpolate's construction rejects them.
        let bareDefault = Curve3D.interpolate(
            points: closePoints, startTangent: tan, endTangent: tan)
        #expect(bareDefault == nil)

        // A tighter explicit tolerance accepts the exact same points.
        let tighter = Curve3D.interpolate(
            points: closePoints, startTangent: tan, endTangent: tan,
            tolerance: 1e-9)
        #expect(tighter != nil)
    }
}
