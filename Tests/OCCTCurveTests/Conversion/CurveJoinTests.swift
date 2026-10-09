import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert CompCurveToBSpline Tests")
struct CurveJoinTests {
    @Test("Join two line segments")
    func joinTwoSegments() throws {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))!

        if let joined = Curve3D.joined(curves: [seg1, seg2]) {
            let dom = joined.domain
            let start = joined.point(at: dom.lowerBound)
            let end = joined.point(at: dom.upperBound)
            #expect(simd_distance(start, SIMD3(0, 0, 0)) < 0.01)
            #expect(simd_distance(end, SIMD3(2, 1, 0)) < 0.01)
        }
    }

    @Test("Join three segments")
    func joinThreeSegments() throws {
        let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0))!
        let seg2 = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 1, 0))!
        let seg3 = Curve3D.segment(from: SIMD3(2, 1, 0), to: SIMD3(3, 1, 1))!

        if let joined = Curve3D.joined(curves: [seg1, seg2, seg3]) {
            let dom = joined.domain
            let start = joined.point(at: dom.lowerBound)
            let end = joined.point(at: dom.upperBound)
            #expect(simd_distance(start, SIMD3(0, 0, 0)) < 0.01)
            #expect(simd_distance(end, SIMD3(3, 1, 1)) < 0.01)
        }
    }

    @Test("Join single curve")
    func joinSingleCurve() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0))!
        if let joined = Curve3D.joined(curves: [seg]) {
            let dom = joined.domain
            let start = joined.point(at: dom.lowerBound)
            let end = joined.point(at: dom.upperBound)
            #expect(simd_distance(start, SIMD3(0, 0, 0)) < 0.01)
            #expect(simd_distance(end, SIMD3(5, 0, 0)) < 0.01)
        }
    }
}
