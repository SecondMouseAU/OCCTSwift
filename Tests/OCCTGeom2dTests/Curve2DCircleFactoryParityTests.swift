import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #411: Curve2D's two centre+radius circle factories

/// `Curve2D.circle(center:radius:)` builds a `Geom2d_Circle` directly;
/// `Curve2D.circleFromCenterRadius(center:radius:)` routes through OCCT's `gce_MakeCirc2d`.
/// Same purpose, same signature, same resulting circle — but `gce_MakeCirc2d` accepts
/// `Radius >= 0`, so the gce factory used to return a live degenerate zero-radius curve where
/// the direct factory returned `nil`. Both now share one radius precondition.
@Suite("Curve2D circle factories agree (#411)")
struct Curve2DCircleFactoryParityTests {

    @Test("Both factories reject zero and negative radius")
    func degenerateRadiusParity() {
        for radius in [0.0, -1.0, -5.0] {
            #expect(Curve2D.circle(center: .zero, radius: radius) == nil)
            #expect(Curve2D.circleFromCenterRadius(center: .zero, radius: radius) == nil)
        }
    }

    @Test("Both factories build the identical circle for a valid radius")
    func validRadiusProducesMatchingGeometry() {
        let center = SIMD2<Double>(3, -4)
        let direct = Curve2D.circle(center: center, radius: 5)
        let gce = Curve2D.circleFromCenterRadius(center: center, radius: 5)
        #expect(direct != nil)
        #expect(gce != nil)
        guard let a = direct, let b = gce else { return }

        #expect(a.isClosed == b.isClosed)
        #expect(a.isPeriodic == b.isPeriodic)
        for t in stride(from: 0.0, to: 2 * .pi, by: .pi / 6) {
            let pa = a.point(at: t)
            let pb = b.point(at: t)
            #expect(abs(pa.x - pb.x) < 1e-9)
            #expect(abs(pa.y - pb.y) < 1e-9)
        }
    }
}
