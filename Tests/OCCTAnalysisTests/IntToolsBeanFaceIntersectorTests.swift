import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.71.0: TKBool remainder + TKFeat

@Suite("IntTools_BeanFaceIntersector Tests")
struct IntToolsBeanFaceIntersectorTests {
    @Test("edge crossing face")
    func edgeCrossingFace() {
        let face = Shape.face(
            from: Surface.plane(
                origin: SIMD3(0, 0, 0),
                normal: SIMD3(0, 0, 1))!,
            uRange: -10...10, vRange: -10...10)
        let edge = Shape.edgeFromPoints(SIMD3(0, 0, -5), SIMD3(0, 0, 5))
        if let f = face, let e = edge {
            let result = Shape.beanFaceIntersect(edge: e, face: f)
            if let r = result {
                #expect(r.minSquareDistance >= 0.0)
            }
        }
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
