import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #415: arc(through:_:_:) delegates to arcOfCircle(start:interior:end:)

/// `Curve3D.arc(through:_:_:)` was documented as an alias for `arcOfCircle(start:interior:end:)`
/// but was actually a second, independently-maintained bridge entry point
/// (`OCCTCurve3DCreateArc3Points`) wrapping the same `GC_MakeArcOfCircle` constructor with a
/// structurally identical body. Nothing enforced the "alias" contract and `arc(through:_:_:)` had
/// zero test coverage. It now delegates directly to `arcOfCircle(start:interior:end:)`; the
/// redundant bridge function was removed.

@Suite("Curve3D.arc(through:_:_:) is a true alias of arcOfCircle (#415)")
struct Curve3DArcAliasParityTests {

    private static let start = SIMD3<Double>(5, 0, 0)
    private static let interior = SIMD3<Double>(0, 5, 0)
    private static let end = SIMD3<Double>(-5, 0, 0)

    @Test("arc(through:_:_:) produces a valid arc")
    func arcThroughThreePoints() {
        let arc = Curve3D.arc(through: Self.start, Self.interior, Self.end)
        #expect(arc != nil)
        if let arc {
            #expect(!arc.isClosed)
            let s = arc.startPoint
            #expect(abs(s.x - Self.start.x) < 0.01)
            #expect(abs(s.y - Self.start.y) < 0.01)
            #expect(abs(s.z - Self.start.z) < 0.01)
        }
    }

    @Test("arc(through:_:_:) and arcOfCircle(start:interior:end:) produce identical geometry")
    func parityWithArcOfCircle() {
        let viaArc = Curve3D.arc(through: Self.start, Self.interior, Self.end)
        let viaArcOfCircle = Curve3D.arcOfCircle(
            start: Self.start, interior: Self.interior, end: Self.end)
        #expect(viaArc != nil)
        #expect(viaArcOfCircle != nil)
        guard let a = viaArc, let b = viaArcOfCircle else { return }
        #expect(a.isClosed == b.isClosed)
        #expect(a.isPeriodic == b.isPeriodic)
        #expect(abs(a.domain.lowerBound - b.domain.lowerBound) < 1e-12)
        #expect(abs(a.domain.upperBound - b.domain.upperBound) < 1e-12)
        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            let ua = a.domain.lowerBound + t * (a.domain.upperBound - a.domain.lowerBound)
            let ub = b.domain.lowerBound + t * (b.domain.upperBound - b.domain.lowerBound)
            let pa = a.point(at: ua)
            let pb = b.point(at: ub)
            #expect(abs(pa.x - pb.x) < 1e-9)
            #expect(abs(pa.y - pb.y) < 1e-9)
            #expect(abs(pa.z - pb.z) < 1e-9)
        }
    }

    @Test("Both entry points reject collinear points")
    func collinearRejectedByBoth() {
        let a = Curve3D.arc(through: SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 0, 0))
        let b = Curve3D.arcOfCircle(
            start: SIMD3(0, 0, 0), interior: SIMD3(1, 0, 0), end: SIMD3(2, 0, 0))
        #expect(a == nil)
        #expect(b == nil)
    }

    @Test("Both entry points reject coincident points")
    func coincidentRejectedByBoth() {
        let p = SIMD3<Double>(3, 4, 5)
        let a = Curve3D.arc(through: p, p, p)
        let b = Curve3D.arcOfCircle(start: p, interior: p, end: p)
        #expect(a == nil)
        #expect(b == nil)
    }
}
