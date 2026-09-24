import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.71.0: TKBool remainder + TKFeat

@Suite("IntTools_BeanFaceIntersector Tests")
struct IntToolsBeanFaceIntersectorTests {
    /// An edge that pierces the face at one point lies on it nowhere, so there is no coincident
    /// range to report: `Scripts/repro/766-intcs-inttools/` measures `Result()` empty on the pinned
    /// kernel. The old body asserted only `minSquareDistance >= 0` inside two `if let`s, which
    /// passed on a refused call and on any distance at all.
    @Test("edge crossing face")
    func edgeCrossingFace() throws {
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let f = try #require(Shape.face(from: plane, uRange: -10...10, vRange: -10...10))
        let e = try #require(Shape.edgeFromPoints(SIMD3(0, 0, -5), SIMD3(0, 0, 5)))
        let r = try #require(Shape.beanFaceIntersect(edge: e, face: f))
        #expect(r.ranges.isEmpty)
    }

    @Test("edge lying on face - coincident ranges")
    func edgeOnFace() {
        let face = Shape.face(
            from: Surface.plane(
                origin: SIMD3(0, 0, 0),
                normal: SIMD3(0, 0, 1))!,
            uRange: -10...10, vRange: -10...10)
        let edge = Shape.edgeFromPoints(SIMD3(-3, 0, 0), SIMD3(3, 0, 0))
        if let f = face, let e = edge {
            let result = Shape.beanFaceIntersect(edge: e, face: f)
            if let r = result {
                #expect(r.ranges.count >= 1)
                if let first = r.ranges.first {
                    #expect(first.last >= first.first)
                }
            }
        }
    }
}
