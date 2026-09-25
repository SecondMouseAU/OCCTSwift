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
    func edgeOnFace() throws {
        // Every fixture, the result and the range are required: the whole body sat under `if let`s,
        // so a nil face, edge, result or empty range list passed with no assertion run. The kernel
        // reports one range, [0, 0] (`Scripts/repro/766-intcs-inttools/`).
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        let f = try #require(Shape.face(from: plane, uRange: -10...10, vRange: -10...10))
        let e = try #require(Shape.edgeFromPoints(SIMD3(-3, 0, 0), SIMD3(3, 0, 0)))
        let r = try #require(Shape.beanFaceIntersect(edge: e, face: f))
        try #require(r.ranges.count == 1)
        let first = try #require(r.ranges.first)
        #expect(first.last >= first.first)
    }
}
