import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools Tests")
struct IntToolsTests {

    @Test func computeVV() {
        guard let v1 = Shape.vertex(at: SIMD3(0, 0, 0)),
            let v2 = Shape.vertex(at: SIMD3(0, 0, 0))
        else { return }
        #expect(IntTools.computeVV(v1, v2) == 0)
    }

    @Test func computeVVDistant() {
        guard let v1 = Shape.vertex(at: SIMD3(0, 0, 0)),
            let v2 = Shape.vertex(at: SIMD3(100, 100, 100))
        else { return }
        #expect(IntTools.computeVV(v1, v2) != 0)
    }

    @Test func intermediatePoint() {
        let mid = IntTools.intermediatePoint(first: 0.0, last: 1.0)
        #expect(mid > 0.0 && mid < 1.0)
    }

    @Test func isDirsCoinside() {
        #expect(IntTools.isDirsCoinside(dx1: 1, dy1: 0, dz1: 0, dx2: 1, dy2: 0, dz2: 0))
        #expect(!IntTools.isDirsCoinside(dx1: 1, dy1: 0, dz1: 0, dx2: 0, dy2: 1, dz2: 0))
    }

    @Test func computeIntRange() {
        let range = IntTools.computeIntRange(tol1: 0.001, tol2: 0.001, angle: .pi / 4)
        #expect(range > 0)
    }
}
