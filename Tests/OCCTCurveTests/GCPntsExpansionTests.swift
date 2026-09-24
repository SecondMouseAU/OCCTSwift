import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GCPnts_AbscissaPoint on edge 0 of the centred 10 box, (-5,-5,-5) -> (-5,-5,5) over
// [0, 10] (Scripts/repro/766-curve-gcpnts-approx/transcript.txt). The earlier versions asserted
// `> 0` or a parameter inside the domain, inside two `if`s each (#766).
@Suite("v0.115.0 - GCPnts Expansion")
struct GCPntsExpansionTests {
    private static func edge0() -> Shape? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let e = box.subShapes(ofType: .edge).first
        else {
            Issue.record("box edge 0 unavailable")
            return nil
        }
        return e
    }

    @Test func edgeArcLength() {
        guard let e = Self.edge0() else { return }
        #expect(abs(e.edgeArcLength - 10) < 1e-12)
    }

    @Test func edgeArcLengthBetween() {
        guard let e = Self.edge0() else { return }
        let domain = e.edgeAdaptorDomain
        let halfLen = e.edgeArcLength(
            from: domain.lowerBound,
            to: (domain.lowerBound + domain.upperBound) / 2.0)
        #expect(abs(halfLen - 5) < 1e-12)
    }

    @Test func edgeParameterAtFraction() {
        guard let e = Self.edge0() else { return }
        #expect(abs(e.edgeParameterAtFraction(0.5) - 5) < 1e-9)
    }

    @Test func edgeParameterAtArcLength() {
        guard let e = Self.edge0() else { return }
        let domain = e.edgeAdaptorDomain
        let param = e.edgeParameterAtArcLength(e.edgeArcLength * 0.5, from: domain.lowerBound)
        #expect(abs(param - 5) < 1e-9)
    }
}
