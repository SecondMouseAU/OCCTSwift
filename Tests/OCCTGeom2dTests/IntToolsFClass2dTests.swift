import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_FClass2d Tests")
struct IntToolsFClass2dTests {
    @Test("Point inside face classified as inside")
    func pointInside() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: 0...10, vRange: 0...10)
            if let f = face {
                let state: PointClassification = f.classifyPoint2d(u: 5, v: 5)
                #expect(state == .inside)
            }
        }
    }

    @Test("Point outside face classified as outside")
    func pointOutside() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: 0...10, vRange: 0...10)
            if let f = face {
                let state: PointClassification = f.classifyPoint2d(u: 15, v: 15)
                #expect(state == .outside)
            }
        }
    }

    @Test("IsHole check")
    func isHoleCheck() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        if let s = plane {
            let face = Shape.face(from: s, uRange: 0...10, vRange: 0...10)
            if let f = face {
                #expect(!f.isHole())
            }
        }
    }
}
